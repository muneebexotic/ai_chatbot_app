// Account deletion — PRD R9.5.2.
//
// "Account deletion removes or anonymizes every row for that user within the
// request, and is exposed in-app (Play requires an in-app deletion path)."
//
// ## Why this needs a function at all
//
// A client cannot delete its own `auth.users` row. That is deliberate: the
// service role bypasses RLS, and handing a client anything that can bypass RLS
// would defeat every policy in the schema. So deletion runs here, where the
// secret key is a Function secret the client never sees.
//
// ## Why one call deletes everything
//
// Every user-owned table in §9.5 references `auth.users(id)` with
// `on delete cascade`, so removing the auth user removes profiles,
// entitlements, usage_daily, partners, threads, messages (through threads),
// sessions, memories, and referrals-as-inviter — in one transaction, which is
// what R9.5.2's "within the request" requires.
//
// Two deliberate exceptions, both `on delete set null`:
//
//   * `referrals.invitee_id` — the inviter's row survives, anonymised. Their
//     referral history is their data too, and deleting it would silently
//     rewrite someone else's record.
//   * `abuse_events.user_id` — the event survives, anonymised. Deletion is a
//     privacy right, not a way to clear an abuse record (DECISIONS D7).
//
// If a future table hangs off `auth.users` without a cascade rule, it will
// silently survive deletion and this comment will be wrong. The migration that
// adds it owns that decision.
//
// ## Identity
//
// The user id comes from verifying the caller's JWT, never from the request
// body. A body-supplied id would let any authenticated caller delete any
// account by guessing a uuid — client input is hostile (R9.3.2).

import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }

  // POST only. Deletion is not idempotent-safe to expose on GET, where a
  // link preview or a prefetch could fire it.
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return json({ error: 'unauthorized' }, 401);
  }

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!url || !anonKey || !serviceKey) {
    // Never echo which one is missing: this response is public.
    console.error('delete-account: missing environment configuration');
    return json({ error: 'server_misconfigured' }, 500);
  }

  // Step 1 — establish who is calling, using their own token and the anon key.
  // This client has no elevated rights; it is only being asked to validate a
  // JWT and report whose it is.
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData?.user) {
    return json({ error: 'unauthorized' }, 401);
  }
  const userId = userData.user.id;

  // Step 2 — delete, as service role, the id established above and no other.
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    console.error('delete-account: deleteUser failed', deleteError.message);
    return json({ error: 'delete_failed' }, 500);
  }

  console.log(`delete-account: removed ${userId}`);
  return json({ deleted: true }, 200);
});
