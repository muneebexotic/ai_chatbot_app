// The gateway — PRD §9.3. Every model call in the product passes through here.
//
// R9.3.1 lists the responsibilities in order, and this file follows that order
// literally so the two can be read side by side:
//
//   1. verify the caller's JWT
//   2. look up entitlement and today's usage
//   3. reject with a typed error if over quota
//   4. apply the abuse checks in §10
//   5. construct the prompt from partner + memory + recent turns
//   6. call the model with the server-held key
//   7. stream the response back
//   8. record usage atomically
//
// Steps 2, 3, 4 and 8 are one call to `consume_model_call`, because doing them
// separately is what makes them racy: two requests that each read "29 used"
// both pass a check for "under 30". The RPC checks and increments inside a
// single statement holding a row lock, and it increments *before* the model
// runs, so a crash costs the user a message rather than granting a free one.
//
// ## What this file exists to prevent
//
// F1 and §16: no secret in the client, ever. The Groq key is a Function secret
// that never leaves this process. Milestone 0 moved keys from source into
// --dart-define, which CRITIQUE W0.3 records as "secrets moved somewhere less
// embarrassing" rather than fixed — an APK is a zip and every string in it is
// public. This is the actual fix, and it is the reason W0.3 can finally be
// closed.
//
// F2: the client displays entitlements and never enforces them. Nothing in the
// request body can change what the server decides. `validateRequest` rejects
// unknown keys, so a forged `{"tier":"pro"}` is a 400, not a silent no-op.

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import {
  GatewayError,
  validateRequest,
  deriveTitle,
} from '../_shared/gateway_contract.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

function fail(error: GatewayError, status: number): Response {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

/// One SSE frame. The client parses this, not Groq's format — the whole point
/// of R9.3.3's provider-agnostic routing is that swapping Groq for Cerebras is
/// a config change, and it would not be if the provider's wire format reached
/// the app.
function sse(event: string, data: unknown): Uint8Array {
  return new TextEncoder().encode(
    `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`,
  );
}

interface Config {
  routes: Record<string, string>;
  generation: {
    temperature: number;
    max_tokens: number;
    history_turns: number;
  };
  safetyPreamble: string;
}

async function loadConfig(admin: SupabaseClient): Promise<Config | null> {
  const { data, error } = await admin
    .from('gateway_config')
    .select('key, value')
    .in('key', ['model_routes', 'generation', 'safety_preamble']);

  if (error || !data) {
    console.error('gateway: config read failed', error?.message);
    return null;
  }

  const byKey = Object.fromEntries(data.map((r) => [r.key, r.value]));
  if (!byKey.model_routes || !byKey.generation || !byKey.safety_preamble) {
    console.error('gateway: config incomplete');
    return null;
  }

  return {
    routes: byKey.model_routes,
    generation: byKey.generation,
    safetyPreamble: byKey.safety_preamble,
  };
}

/// Records an abuse event. Never throws and never blocks the response: a
/// failure to write the audit row must not become a failure to serve the user.
async function note(
  admin: SupabaseClient,
  userId: string | null,
  kind: string,
  detail: Record<string, unknown>,
): Promise<void> {
  try {
    await admin.from('abuse_events').insert({ user_id: userId, kind, detail });
  } catch (e) {
    console.error('gateway: abuse_events insert failed', e);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return fail({ code: 'invalid_request' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const groqKey = Deno.env.get('GROQ_API_KEY');

  if (!url || !anonKey || !serviceKey || !groqKey) {
    // Never say which one. This response is public.
    console.error('gateway: missing environment configuration');
    return fail({ code: 'server_misconfigured' }, 500);
  }

  // ── 1. Who is calling ──────────────────────────────────────────────────────
  //
  // From the verified JWT, never from the body. A body-supplied user id would
  // let any authenticated caller spend someone else's quota and read their
  // memories.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return fail({ code: 'unauthorized' }, 401);
  }

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData?.user) {
    return fail({ code: 'unauthorized' }, 401);
  }
  const user = userData.user;

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // R10.2: "email verification required before any model call, to stop
  // free-tier farming." Checked here rather than trusted from a client flag.
  //
  // kalaam-dev has confirmation switched off so integration tests can create
  // users, which means `email_confirmed_at` is set at signup there and this is
  // a no-op against dev. It is load-bearing against prod, where confirmation
  // is on and must stay on.
  if (!user.email_confirmed_at) {
    await note(admin, user.id, 'unconfirmed_email_call', { email: user.email });
    return fail({ code: 'email_not_confirmed' }, 403);
  }

  // ── Request shape ──────────────────────────────────────────────────────────
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail({ code: 'invalid_request', field: 'body' }, 400);
  }

  const parsed = validateRequest(body);
  if (!parsed.ok) {
    // A client sending fields the contract does not define is either broken or
    // probing. Either way it is worth a row.
    await note(admin, user.id, 'invalid_request', {
      field: parsed.error.field ?? null,
    });
    return fail(parsed.error, 400);
  }
  const request = parsed.value;

  const config = await loadConfig(admin);
  if (!config) return fail({ code: 'server_misconfigured' }, 500);

  // ── 2, 3, 4, 8. Entitlement, quota, fair use, circuit breaker ─────────────
  const { data: decision, error: rpcError } = await admin.rpc(
    'consume_model_call',
    { p_user_id: user.id, p_kind: 'message' },
  );

  if (rpcError || !decision) {
    console.error('gateway: consume_model_call failed', rpcError?.message);
    return fail({ code: 'server_misconfigured' }, 500);
  }

  if (!decision.allowed) {
    switch (decision.reason) {
      case 'at_capacity':
        // R10.4: a clear "at capacity" state, not an error. Expected to fire
        // in normal operation given the free-tier ceilings in RESEARCH §4.A.
        return fail({ code: 'at_capacity' }, 503);
      case 'rate_limited':
        await note(admin, user.id, 'rate_limited', {
          hourly_ceiling_hit: true,
        });
        return fail(
          {
            code: 'rate_limited',
            retryAfterSeconds: decision.retry_after_seconds,
          },
          429,
        );
      case 'quota_exceeded':
        return fail(
          {
            code: 'quota_exceeded',
            resetsAt: decision.resets_at,
            upgradeable: decision.upgradeable,
          },
          429,
        );
      default:
        console.error('gateway: unusable decision', decision);
        return fail({ code: 'server_misconfigured' }, 500);
    }
  }

  // ── 5. Build the prompt ────────────────────────────────────────────────────
  //
  // Partner, then memory, then recent turns. Read under service role because
  // `partners.system_prompt` is revoked from `authenticated` (see the gateway
  // migration) — the prompt is server-decided, so only the server reads it.

  const { data: partner } = await admin
    .from('partners')
    .select('id, name, system_prompt, is_builtin, owner_id, visibility')
    .eq('id', request.partnerId)
    .maybeSingle();

  // A partner the caller may use: a built-in, or one they own. Checked rather
  // than assumed — a uuid in a request body is a claim, not a permission. §6.2
  // will add publicly published partners; until they exist and have been
  // reviewed, this stays closed.
  const mayUse =
    partner &&
    ((partner.is_builtin && partner.visibility === 'public') ||
      partner.owner_id === user.id);

  if (!mayUse) {
    await note(admin, user.id, 'partner_access_denied', {
      partner_id: request.partnerId,
    });
    return fail({ code: 'invalid_request', field: 'partnerId' }, 400);
  }

  // Thread: either one the caller owns, or a new one. `eq('user_id', user.id)`
  // is what turns a guessed uuid into a miss rather than into someone else's
  // conversation.
  let threadId = request.threadId;
  let isNewThread = false;

  if (threadId) {
    const { data: thread } = await admin
      .from('threads')
      .select('id')
      .eq('id', threadId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!thread) {
      await note(admin, user.id, 'thread_access_denied', { thread_id: threadId });
      return fail({ code: 'invalid_request', field: 'threadId' }, 400);
    }
  } else {
    const { data: created, error: createError } = await admin
      .from('threads')
      .insert({
        user_id: user.id,
        partner_id: partner.id,
        title: deriveTitle(request.text),
      })
      .select('id')
      .single();

    if (createError || !created) {
      console.error('gateway: thread insert failed', createError?.message);
      return fail({ code: 'upstream_failed' }, 500);
    }
    threadId = created.id;
    isNewThread = true;
  }

  // R5.2.3: "Memory is injected into the session prompt so the partner
  // references prior sessions naturally."
  const { data: memories } = await admin
    .from('memories')
    .select('content')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(20);

  // Recent turns, oldest first for the model. `history_turns` is server config
  // and is both a cost ceiling and the reason a long thread cannot exceed the
  // 12K tokens-per-minute free-tier limit on its own.
  const { data: history } = await admin
    .from('messages')
    .select('role, content')
    .eq('thread_id', threadId)
    .order('created_at', { ascending: false })
    .limit(config.generation.history_turns);

  const memoryBlock = memories?.length
    ? `\n\nWhat you remember about this person, from earlier conversations. ` +
      `Refer to it naturally when it is relevant, and never recite it back as ` +
      `a list:\n${memories.map((m) => `- ${m.content}`).join('\n')}`
    : '';

  const messages = [
    {
      role: 'system',
      // The safety preamble comes FIRST and the partner's own prompt second, so
      // R10.6's crisis instruction is never something a partner prompt can be
      // read as overriding. It also cannot be omitted: it lives in
      // gateway_config, not in the partner row, so a new built-in or a
      // user-authored custom partner (§5.3.2) inherits it automatically.
      content:
        `${config.safetyPreamble}\n\nYour role in this conversation:\n` +
        `${partner.system_prompt}${memoryBlock}`,
    },
    ...(history ?? []).reverse().map((m) => ({
      role: m.role as 'user' | 'assistant',
      content: m.content,
    })),
    { role: 'user', content: request.text },
  ];

  // Persist the user's message before the model runs. If the model call fails,
  // R11.5 requires the transcript to survive — the user said it, and losing
  // their words because a third party was slow is not acceptable.
  const { data: userMessage, error: userMessageError } = await admin
    .from('messages')
    .insert({ thread_id: threadId, role: 'user', content: request.text })
    .select('id, created_at')
    .single();

  if (userMessageError || !userMessage) {
    console.error('gateway: user message insert failed', userMessageError?.message);
    return fail({ code: 'upstream_failed' }, 500);
  }

  // ── 6, 7. Call the model and stream it back ────────────────────────────────
  let upstream: Response;
  try {
    upstream = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${groqKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        // Every one of these is server-decided (R9.3.2). None of them appears
        // in GatewayRequest, so none of them is reachable from the client.
        model: config.routes.chat,
        temperature: config.generation.temperature,
        max_tokens: config.generation.max_tokens,
        stream: true,
        messages,
      }),
    });
  } catch (e) {
    console.error('gateway: upstream fetch threw', e);
    return fail({ code: 'upstream_failed' }, 502);
  }

  if (!upstream.ok || !upstream.body) {
    const detail = await upstream.text().catch(() => '');
    console.error(`gateway: upstream ${upstream.status}`, detail.slice(0, 300));
    // 429 from the provider is our capacity problem, not the user's quota.
    // Telling them "you are out of messages" when the truth is "we are out"
    // would be a false statement about their account.
    if (upstream.status === 429) return fail({ code: 'at_capacity' }, 503);
    return fail({ code: 'upstream_failed' }, 502);
  }

  const stream = new ReadableStream({
    async start(controller) {
      controller.enqueue(
        sse('meta', {
          threadId,
          isNewThread,
          userMessageId: userMessage.id,
          usage: {
            used: decision.used,
            dailyLimit: decision.daily_limit,
            tier: decision.tier,
            resetsAt: decision.resets_at,
          },
        }),
      );

      const reader = upstream.body!.getReader();
      const decoder = new TextDecoder();
      let buffered = '';
      let full = '';
      let finishReason: string | null = null;

      try {
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;

          buffered += decoder.decode(value, { stream: true });

          // SSE frames are separated by a blank line, and a chunk boundary can
          // land anywhere — including mid-frame. Anything after the last
          // separator stays buffered for the next read.
          const frames = buffered.split('\n\n');
          buffered = frames.pop() ?? '';

          for (const frame of frames) {
            const line = frame.split('\n').find((l) => l.startsWith('data: '));
            if (!line) continue;
            const payload = line.slice(6).trim();
            if (payload === '[DONE]') continue;

            try {
              const parsedFrame = JSON.parse(payload);
              const choice = parsedFrame.choices?.[0];
              const delta = choice?.delta?.content;
              if (choice?.finish_reason) finishReason = choice.finish_reason;
              if (typeof delta === 'string' && delta.length > 0) {
                full += delta;
                controller.enqueue(sse('delta', { text: delta }));
              }
            } catch {
              // A frame we cannot parse is a provider change, not a user
              // problem. Skip it rather than tearing down a reply in progress.
              console.error('gateway: unparseable upstream frame');
            }
          }
        }

        // R10.5: on a safety block, show a plain non-judgemental message and do
        // NOT retry automatically. Nothing here retries.
        if (finishReason === 'content_filter') {
          await note(admin, user.id, 'safety_block', { thread_id: threadId });
          controller.enqueue(sse('error', { code: 'safety_blocked' }));
          controller.close();
          return;
        }

        if (full.trim().length === 0) {
          controller.enqueue(sse('error', { code: 'upstream_failed' }));
          controller.close();
          return;
        }

        const { data: assistantMessage } = await admin
          .from('messages')
          .insert({ thread_id: threadId, role: 'assistant', content: full })
          .select('id')
          .single();

        // Touch the thread so the list orders by real activity. `updated_at` is
        // set by the trigger, not by this client's clock (§9.4).
        await admin
          .from('threads')
          .update({ partner_id: partner.id })
          .eq('id', threadId);

        controller.enqueue(
          sse('done', {
            messageId: assistantMessage?.id ?? null,
            // `truncated` is honest rather than cosmetic: the reply stopped
            // because it hit max_tokens, and the UI should not pretend the
            // model chose to end there.
            truncated: finishReason === 'length',
          }),
        );
      } catch (e) {
        console.error('gateway: stream failed', e);
        // Persist whatever arrived. A half-answer the user watched appear is
        // worth more than a gap in the transcript, and R11.5 is explicit that
        // a failure must not lose their work.
        if (full.trim().length > 0) {
          await admin
            .from('messages')
            .insert({ thread_id: threadId, role: 'assistant', content: full });
        }
        controller.enqueue(sse('error', { code: 'upstream_failed' }));
      } finally {
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      ...cors,
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
});
