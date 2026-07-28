// Memory extraction — PRD §5.2.
//
// R5.2.1: "After each session or long chat, the server extracts up to 3 durable
// facts the user stated about themselves (goal, level, context, preferences)
// and stores them as short strings."
//
// ## Why this is a separate function from the gateway
//
// Latency. R4.2.4 budgets under 1.5s from end-of-speech to the first spoken
// word, and extraction is a second model call that nobody is waiting for. Doing
// it inline would put it on the critical path of every reply for the benefit of
// a feature that is allowed to be seconds late — or to fail entirely, since a
// missed extraction costs a remembered fact and nothing else.
//
// The client fires this after a reply completes and ignores the result.
//
// ## What it may store
//
// Three facts, filtered twice: an explicit deny-instruction in the prompt and a
// deterministic keyword filter over the candidates, both in
// `_shared/memory_filter.ts`, both required by R5.2.4. §0.5.2 puts these
// categories on the closed list, which is why the filter over-rejects on
// purpose.

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { EXTRACTION_PROMPT, filterMemories } from '../_shared/memory_filter.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/// A conversation shorter than this has nothing durable in it, and asking
/// anyway spends a model call from a shared free quota to be told so.
const MIN_MESSAGES = 4;

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

async function note(
  admin: SupabaseClient,
  userId: string | null,
  kind: string,
  detail: Record<string, unknown>,
): Promise<void> {
  try {
    await admin.from('abuse_events').insert({ user_id: userId, kind, detail });
  } catch (e) {
    console.error('extract-memory: abuse_events insert failed', e);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'invalid_request' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const groqKey = Deno.env.get('GROQ_API_KEY');

  if (!url || !anonKey || !serviceKey || !groqKey) {
    console.error('extract-memory: missing environment configuration');
    return json({ error: 'server_misconfigured' }, 500);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return json({ error: 'unauthorized' }, 401);
  }

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData?.user) return json({ error: 'unauthorized' }, 401);
  const user = userData.user;

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_request' }, 400);
  }

  const threadId = body.threadId;
  if (typeof threadId !== 'string' || !UUID.test(threadId)) {
    return json({ error: 'invalid_request', field: 'threadId' }, 400);
  }

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Ownership from the verified JWT, never from the body.
  const { data: thread } = await admin
    .from('threads')
    .select('id')
    .eq('id', threadId)
    .eq('user_id', user.id)
    .maybeSingle();

  if (!thread) {
    await note(admin, user.id, 'thread_access_denied', {
      thread_id: threadId,
      via: 'extract-memory',
    });
    return json({ error: 'invalid_request', field: 'threadId' }, 400);
  }

  const { data: config } = await admin
    .from('gateway_config')
    .select('key, value')
    .in('key', ['model_routes', 'generation', 'limits']);

  const byKey = Object.fromEntries((config ?? []).map((r) => [r.key, r.value]));
  const model = byKey.model_routes?.memory;
  const maxTokens = byKey.generation?.memory_max_tokens ?? 256;
  const freeMemoryItems = byKey.limits?.free_memory_items ?? 10;

  if (!model) {
    console.error('extract-memory: no memory route configured');
    return json({ error: 'server_misconfigured' }, 500);
  }

  // §8: free users keep 10 memories, Pro is unlimited. Enforced here because
  // F2 makes entitlement server truth — a client-side cap is a suggestion.
  const { data: entitlement } = await admin
    .from('entitlements')
    .select('tier, state, expires_at')
    .eq('user_id', user.id)
    .maybeSingle();

  const isPro =
    entitlement?.tier === 'pro' &&
    ['active', 'grace'].includes(entitlement.state) &&
    (!entitlement.expires_at || new Date(entitlement.expires_at) > new Date());

  const { count: storedCount } = await admin
    .from('memories')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id);

  const remaining = isPro ? Number.MAX_SAFE_INTEGER : freeMemoryItems - (storedCount ?? 0);
  if (remaining <= 0) {
    // Full is not an error. R5.2.2 gives the user a Memory screen where they
    // can delete items, so the fix is in their hands and does not need a
    // paywall interruption — R8.3 allows exactly two, and this is neither.
    return json({ stored: 0, reason: 'memory_full' }, 200);
  }

  const { data: history } = await admin
    .from('messages')
    .select('role, content')
    .eq('thread_id', threadId)
    .order('created_at', { ascending: false })
    .limit(20);

  if (!history || history.length < MIN_MESSAGES) {
    return json({ stored: 0, reason: 'too_short' }, 200);
  }

  // The same ceilings as any other model call. Extraction is not billed to the
  // user's daily message allowance — they did not ask for it — but it does
  // consume the shared free quota R10.1 and R10.4 exist to protect, so it is
  // counted there.
  const { data: decision } = await admin.rpc('consume_model_call', {
    p_user_id: user.id,
    p_kind: 'memory',
  });

  if (!decision?.allowed) {
    // Silently skipped. Extraction is invisible to the user by design, and an
    // error about a background job they never started would be noise.
    return json({ stored: 0, reason: decision?.reason ?? 'not_allowed' }, 200);
  }

  const transcript = history
    .reverse()
    .map((m) => `${m.role === 'user' ? 'User' : 'Partner'}: ${m.content}`)
    .join('\n');

  let candidates: string[] = [];
  try {
    const upstream = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${groqKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        temperature: 0,
        max_tokens: maxTokens,
        // Structured output: the alternative is parsing prose, and a parser
        // that guesses is a parser that eventually stores a sentence fragment.
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: EXTRACTION_PROMPT },
          { role: 'user', content: transcript },
        ],
      }),
    });

    if (!upstream.ok) {
      console.error(`extract-memory: upstream ${upstream.status}`);
      return json({ stored: 0, reason: 'upstream_failed' }, 200);
    }

    const payload = await upstream.json();
    const content = payload.choices?.[0]?.message?.content ?? '{}';
    const parsed = JSON.parse(content);
    candidates = Array.isArray(parsed.facts)
      ? parsed.facts.filter((f: unknown): f is string => typeof f === 'string')
      : [];
  } catch (e) {
    console.error('extract-memory: extraction failed', e);
    return json({ stored: 0, reason: 'upstream_failed' }, 200);
  }

  // R5.2.1 caps this at three. Applied before the filter so a model that
  // returns twelve facts cannot have eleven of them silently considered.
  const { kept, rejected } = filterMemories(candidates.slice(0, 3));

  if (rejected.length > 0) {
    // Recorded because it is the evidence that the second half of R5.2.4 is
    // doing something. A filter that never logs a rejection is indistinguishable
    // from a filter that never runs.
    //
    // The rejected TEXT is not stored — writing the sensitive string into
    // abuse_events to prove it was not written into memories would defeat the
    // requirement precisely.
    await note(admin, user.id, 'memory_rejected', {
      categories: rejected.map((r) => r.category),
      count: rejected.length,
    });
  }

  if (kept.length === 0) return json({ stored: 0, reason: 'nothing_durable' }, 200);

  // De-duplicate against what is already stored. Without this, a user who says
  // "I have an interview on Tuesday" in three conversations accumulates three
  // identical rows and spends their free allowance of ten on one fact.
  const { data: existing } = await admin
    .from('memories')
    .select('content')
    .eq('user_id', user.id);

  const seen = new Set((existing ?? []).map((m) => m.content.toLowerCase()));
  const fresh = kept
    .filter((c) => !seen.has(c.toLowerCase()))
    .slice(0, Math.min(remaining, 3));

  if (fresh.length === 0) return json({ stored: 0, reason: 'already_known' }, 200);

  const { error: insertError } = await admin.from('memories').insert(
    fresh.map((content) => ({ user_id: user.id, content })),
  );

  if (insertError) {
    console.error('extract-memory: insert failed', insertError.message);
    return json({ stored: 0, reason: 'storage_failed' }, 200);
  }

  return json({ stored: fresh.length }, 200);
});
