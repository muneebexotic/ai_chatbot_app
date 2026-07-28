// The session lifecycle — PRD §4.2, §8, R10.1, F2.
//
// Three actions: open, heartbeat, close. Between them they are the only way
// `usage_daily.voice_seconds` is ever written.
//
// ## Why this is a separate function from the gateway
//
// The gateway streams SSE and exists to make one model call. This makes none.
// Folding session bookkeeping into it would mean a streaming response type for
// a request that returns a small JSON object, and a second set of branches in
// the file that R9.3.1 asks to be readable next to its own requirement list.
//
// ## Why the client cannot cheat the meter
//
// Nothing here reads a duration from the request body. `meter_voice_session`
// charges `now() - last_metered_at` using the database clock, so the only way
// to spend fewer seconds is to spend less time. F2 is explicit that the client
// "only *displays*" quota, and a client-supplied `secondsSpoken` would be
// precisely the defect it names.
//
// A client can still stop sending heartbeats. It cannot stop the gateway: every
// spoken turn meters before it answers, so a session that dodges the meter is a
// session with no AI in it. Heartbeats only cover the gaps between turns, and
// the per-call clamp bounds what a dropped one costs in either direction.

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import {
  GatewayError,
  validateSessionRequest,
} from '../_shared/gateway_contract.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

function fail(error: GatewayError, status: number): Response {
  return json({ error }, status);
}

/// Maps an RPC refusal onto the same error codes the gateway uses, so the
/// client's single `_failureForCode` switch covers both endpoints. Two
/// vocabularies for one concept is how a UI ends up with a generic snackbar,
/// which R11.5 forbids.
function refusal(decision: Record<string, unknown>): Response {
  switch (decision.reason) {
    case 'quota_exceeded':
      return fail(
        {
          code: 'quota_exceeded',
          resetsAt: decision.resets_at as string | undefined,
          upgradeable: decision.upgradeable as boolean | undefined,
        },
        429,
      );
    case 'not_found':
    case 'not_open':
      // Deliberately the same answer for both. "Not open" tells a prober that
      // the id was real; "not found" alone tells them nothing.
      return fail({ code: 'invalid_request', field: 'sessionId' }, 400);
    default:
      console.error('session: unusable decision', decision);
      return fail({ code: 'server_misconfigured' }, 500);
  }
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
    console.error('session: abuse_events insert failed', e);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return fail({ code: 'invalid_request' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!url || !anonKey || !serviceKey) {
    console.error('session: missing environment configuration');
    return fail({ code: 'server_misconfigured' }, 500);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return fail({ code: 'unauthorized' }, 401);
  }

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData?.user) return fail({ code: 'unauthorized' }, 401);
  const user = userData.user;

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // R10.2, same as the gateway: email verification before anything that costs
  // quota, to stop free-tier farming.
  if (!user.email_confirmed_at) {
    await note(admin, user.id, 'unconfirmed_email_call', { email: user.email });
    return fail({ code: 'email_not_confirmed' }, 403);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return fail({ code: 'invalid_request', field: 'body' }, 400);
  }

  const parsed = validateSessionRequest(body);
  if (!parsed.ok) {
    await note(admin, user.id, 'invalid_request', {
      endpoint: 'session',
      field: parsed.error.field ?? null,
    });
    return fail(parsed.error, 400);
  }
  const request = parsed.value;

  switch (request.action) {
    // ── open ─────────────────────────────────────────────────────────────────
    case 'open': {
      // The partner must be one the caller may use. Same check as the gateway:
      // a uuid in a request body is a claim, not a permission.
      const { data: partner } = await admin
        .from('partners')
        .select('id, is_builtin, owner_id, visibility')
        .eq('id', request.partnerId!)
        .maybeSingle();

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

      if (request.threadId) {
        const { data: thread } = await admin
          .from('threads')
          .select('id')
          .eq('id', request.threadId)
          .eq('user_id', user.id)
          .maybeSingle();
        if (!thread) {
          await note(admin, user.id, 'thread_access_denied', {
            thread_id: request.threadId,
          });
          return fail({ code: 'invalid_request', field: 'threadId' }, 400);
        }
      }

      const { data: decision, error } = await admin.rpc('open_voice_session', {
        p_user_id: user.id,
        p_partner_id: request.partnerId,
        p_thread_id: request.threadId,
        p_goal: request.goal,
      });

      if (error || !decision) {
        console.error('session: open_voice_session failed', error?.message);
        return fail({ code: 'server_misconfigured' }, 500);
      }
      if (!decision.allowed) return refusal(decision);

      return json({
        sessionId: decision.session_id,
        usage: {
          tier: decision.tier,
          usedSeconds: decision.used_seconds,
          dailyLimitSeconds: decision.daily_limit_seconds,
          remainingSeconds: decision.remaining_seconds,
          resetsAt: decision.resets_at,
        },
      });
    }

    // ── heartbeat ────────────────────────────────────────────────────────────
    //
    // Returns the remaining allowance so the client can DISPLAY it (F2). Note
    // that a refusal here is not an instruction to hang up: R8.3 requires the
    // exchange in flight to finish before the cap is shown, so the client
    // reads `allowed: false` and ends after the current turn.
    case 'heartbeat': {
      const { data: decision, error } = await admin.rpc('meter_voice_session', {
        p_user_id: user.id,
        p_session_id: request.sessionId,
      });

      if (error || !decision) {
        console.error('session: meter_voice_session failed', error?.message);
        return fail({ code: 'server_misconfigured' }, 500);
      }

      if (decision.reason === 'not_found' || decision.reason === 'not_open') {
        return refusal(decision);
      }

      return json({
        allowed: decision.allowed,
        usage: {
          tier: decision.tier,
          usedSeconds: decision.used_seconds,
          dailyLimitSeconds: decision.daily_limit_seconds,
          remainingSeconds: decision.remaining_seconds,
          resetsAt: decision.resets_at,
          upgradeable: decision.upgradeable,
        },
      });
    }

    // ── close ────────────────────────────────────────────────────────────────
    case 'close': {
      const { data: decision, error } = await admin.rpc('close_voice_session', {
        p_user_id: user.id,
        p_session_id: request.sessionId,
        p_duration_seconds: request.durationSeconds,
        p_metrics: request.metrics,
      });

      if (error || !decision) {
        console.error('session: close_voice_session failed', error?.message);
        return fail({ code: 'server_misconfigured' }, 500);
      }
      if (!decision.closed) {
        return fail({ code: 'invalid_request', field: 'sessionId' }, 400);
      }

      const usage = decision.usage ?? {};
      return json({
        closed: true,
        usage: {
          tier: usage.tier,
          usedSeconds: usage.used_seconds,
          dailyLimitSeconds: usage.daily_limit_seconds,
          remainingSeconds: usage.remaining_seconds,
          resetsAt: usage.resets_at,
        },
      });
    }
  }
});
