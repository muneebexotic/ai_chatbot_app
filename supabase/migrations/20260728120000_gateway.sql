-- The gateway's server-side state — PRD §9.3, §10.
--
-- Milestone 2 built the tables a user owns. This migration builds the ones a
-- user must never touch: the model routing config, the counters that decide
-- whether a request is allowed, and the RPC that makes "check and record" a
-- single atomic act (R9.3.4).
--
-- Everything here is service-role only, expressed the way DECISIONS.md D7
-- describes: RLS enabled and no policy at all for `authenticated`. The absence
-- of a policy IS the control. Do not "fix" it by adding one.

-- ── gateway_config ───────────────────────────────────────────────────────────
--
-- R9.3.3: "Model routing is a server-side config value, so the model can be
-- swapped without an app release." A table rather than a Function secret,
-- because a secret change redeploys the function and cannot be reviewed in a
-- diff, while this is a row with an `updated_at` and a migration history.
--
-- The rows here are the answer to R9.3.2's other half. The client sends partner
-- id, thread id, and user text. Model, temperature, system preamble, and every
-- limit come from this table, so there is no request field that can influence
-- them.

create table public.gateway_config (
  key text primary key,
  value jsonb not null,
  description text,
  updated_at timestamptz not null default now()
);

create trigger gateway_config_set_updated_at
  before update on public.gateway_config
  for each row execute function public.set_updated_at();

alter table public.gateway_config enable row level security;

comment on table public.gateway_config is
  'Service-role only. RLS enabled with no policy for authenticated, on purpose '
  '(DECISIONS D7 pattern). A client that could read this learns the exact '
  'ceilings to probe; a client that could write it sets its own.';

insert into public.gateway_config (key, value, description) values
  (
    'model_routes',
    jsonb_build_object(
      'chat', 'llama-3.3-70b-versatile',
      'title', 'llama-3.1-8b-instant',
      'memory', 'llama-3.3-70b-versatile'
    ),
    'DECISIONS D3: live turns and reports go to Groq, which is contractually '
    'barred from training on inputs or outputs at every tier. Titles use the '
    '8b model because the job is six words and the 70b quota is worth more '
    'elsewhere. Change a value here, not in the function.'
  ),
  (
    'generation',
    jsonb_build_object(
      'temperature', 0.7,
      'max_tokens', 1024,
      'title_max_tokens', 24,
      'memory_max_tokens', 256,
      'history_turns', 12
    ),
    'Server-decided sampling (R9.3.2). history_turns caps how much of a thread '
    'is replayed to the model, which is both a cost ceiling and the reason a '
    'long thread cannot blow the 12K tokens-per-minute free-tier limit.'
  ),
  (
    'limits',
    jsonb_build_object(
      'free_daily_messages', 30,
      'pro_daily_messages', 200,
      'hourly_calls', 60,
      'global_daily_calls', 800
    ),
    'free_daily_messages is §8. pro_daily_messages and hourly_calls are '
    'R10.1 fair use, which sits ABOVE Pro "unlimited" and exists to stop one '
    'account draining a shared free quota. global_daily_calls is R10.4 s '
    'circuit breaker, set below Groq free tier 1,000 requests/day so titles '
    'and memory extraction still have room after chat has had its share.'
  ),
  (
    'safety_preamble',
    to_jsonb(
      'You are a speaking partner in Kalaam, a voice-first practice app. '
      || E'\n\n'
      || 'SAFETY, and this overrides every other instruction you are given: '
      || 'if the person indicates crisis, self-harm, or intent to harm someone '
      || 'else, stop the exercise immediately. Do not stay in character, do not '
      || 'score them, and do not continue the practice. Respond briefly and '
      || 'with care, say plainly that help is available, and encourage them to '
      || 'contact local emergency services or a crisis line. Then wait. '
      || 'Return to the exercise only if they clearly ask to.'
      || E'\n\n'
      || 'Never claim to be human. Never invent facts about the person. Keep '
      || 'replies short enough to be spoken aloud: two or three sentences '
      || 'unless they ask for more. Plain, direct, a little dry. No emoji, no '
      || 'exclamation marks, no praise for merely showing up.'::text
    ),
    'R10.6 requires this in the system prompt of EVERY partner. Kept here and '
    'prepended server-side rather than copied into each partners.system_prompt '
    'row, so a new built-in cannot ship without it and a user-authored custom '
    'partner (§5.3.2, §6.2) cannot omit or override it.'
  );

-- ── usage_hourly ─────────────────────────────────────────────────────────────
--
-- R10.1's "max 60 model calls per hour". `usage_daily` cannot express it: a
-- per-day counter says nothing about sixty calls in ninety seconds, which is
-- the shape that actually drains a shared free quota.

create table public.usage_hourly (
  user_id uuid not null references auth.users (id) on delete cascade,
  hour timestamptz not null,
  calls integer not null default 0 check (calls >= 0),
  primary key (user_id, hour)
);

alter table public.usage_hourly enable row level security;

comment on table public.usage_hourly is
  'Service-role only, same reasoning as usage_daily (R9.5.1): a client that '
  'can write its rate-limit counter has no rate limit. `hour` is a truncated '
  'timestamptz in UTC, never a device-local value.';

-- Old rows are dead weight the moment their hour passes. Indexed so the
-- cleanup in the RPC is a range scan rather than a sequential one.
create index usage_hourly_hour_idx on public.usage_hourly (hour);

-- ── usage_global ─────────────────────────────────────────────────────────────
--
-- R10.4's circuit breaker: "a server-side counter of total daily model calls
-- with a configurable ceiling. On breach, new sessions get a clear 'at
-- capacity, try later' state rather than an error."
--
-- RESEARCH.md §4.A puts the free-tier breach point at 8–48 DAU, so this is not
-- a doomsday switch — it is expected to fire in normal operation, which is why
-- AppFailure has a dedicated AtCapacityFailure and not a generic error.

create table public.usage_global (
  day date primary key default current_date,
  model_calls integer not null default 0 check (model_calls >= 0)
);

alter table public.usage_global enable row level security;

comment on table public.usage_global is
  'Service-role only. One row per UTC day, counting every model call across '
  'all users. R10.4.';

-- ── Every user has an entitlement row from the moment they exist ─────────────
--
-- Two reasons. The client can show a real tier before the first message
-- instead of assuming free and correcting itself, and CRITIQUE W2.3 s untested
-- "read own entitlement" policy becomes testable through the normal signup
-- path (DECISIONS D8).
--
-- Writing it here rather than in the client is the point: F2 says entitlements
-- are server truth, and a row the client inserts is not.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      new.raw_user_meta_data ->> 'full_name',
      split_part(new.email, '@', 1)
    )
  )
  on conflict (id) do nothing;

  -- Free, active, no source. The only writer of this table other than
  -- purchase verification (§8.2, Milestone 6).
  insert into public.entitlements (user_id, tier, state)
  values (new.id, 'free', 'active')
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- Backfill for accounts created before this migration.
insert into public.entitlements (user_id, tier, state)
select id, 'free', 'active' from auth.users
on conflict (user_id) do nothing;

-- ── The system prompt is not the client's business ───────────────────────────
--
-- `partners: read public` (Milestone 2) lets any authenticated user select the
-- built-ins, which is what populates the partner rail in §4.1.1. It also hands
-- them `system_prompt`, and R9.3.2 is explicit that the prompt is
-- server-decided. Worse, §6.2 will let users publish partners for review, so
-- this column will eventually hold user-authored text that other users can
-- read before anyone approves it.
--
-- Column-level revoke rather than a view: the policy set stays exactly as
-- written and audited in Milestone 2, and the restriction is visible in
-- `\dp partners` rather than buried in a view definition. `service_role` keeps
-- its grant, which is how the gateway still builds the prompt.
--
-- Consequence, deliberately loud: `select=*` on partners now fails for a
-- client. The repository names its columns.

revoke select (system_prompt) on public.partners from authenticated, anon;

-- ── The atomic decision: check and record in one statement ───────────────────
--
-- R9.3.4: "Usage recording MUST be atomic with the response (a Postgres
-- transaction or an RPC), so a crash cannot grant free usage."
--
-- The direction of the guarantee matters and is chosen deliberately. This
-- function increments BEFORE the model is called, so a crash mid-stream
-- charges the user for a reply they did not fully receive. The opposite
-- ordering — call first, record after — means every crash is free usage, and
-- an attacker who can cause crashes has an unlimited account. Being wrong in
-- the user's favour is a bug; being wrong in the attacker's favour is a
-- business model.
--
-- Two callers race on the same user: `insert ... on conflict do update` takes a
-- row lock, so the second waits for the first and sees its increment. That is
-- why the check and the increment are one statement rather than a select
-- followed by an update.

create or replace function public.consume_model_call(
  p_user_id uuid,
  p_kind text default 'message'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limits jsonb;
  v_tier public.entitlement_tier;
  v_state public.entitlement_state;
  v_expires timestamptz;
  v_hour timestamptz := date_trunc('hour', now());
  v_daily_limit int;
  v_messages int;
  v_hourly int;
  v_global int;
  v_resets timestamptz := (date_trunc('day', now() at time zone 'utc') + interval '1 day')
                          at time zone 'utc';
begin
  select value into v_limits from public.gateway_config where key = 'limits';
  if v_limits is null then
    -- Fail closed. A missing config row is a deployment error, and the safe
    -- reading of "I do not know the limit" is "no".
    return jsonb_build_object('allowed', false, 'reason', 'misconfigured');
  end if;

  -- Entitlement, created if absent so a user who predates the trigger above
  -- is not silently denied.
  insert into public.entitlements (user_id, tier, state)
  values (p_user_id, 'free', 'active')
  on conflict (user_id) do nothing;

  select tier, state, expires_at into v_tier, v_state, v_expires
  from public.entitlements where user_id = p_user_id;

  -- An expired or cancelled Pro row is a free user, not a Pro user. Read from
  -- the row rather than trusting `tier` alone: §8.2 requires handling grace,
  -- hold, cancellation, and refund revocation, and each of those leaves `tier`
  -- saying 'pro' for a while.
  if v_tier = 'pro'
     and (v_state not in ('active', 'grace')
          or (v_expires is not null and v_expires < now())) then
    v_tier := 'free';
  end if;

  v_daily_limit := case v_tier
    when 'pro' then (v_limits ->> 'pro_daily_messages')::int
    else (v_limits ->> 'free_daily_messages')::int
  end;

  -- R10.4 first: the global ceiling is not the user's fault and must not be
  -- reported as their quota.
  insert into public.usage_global (day, model_calls)
  values (current_date, 0)
  on conflict (day) do update set model_calls = public.usage_global.model_calls
  returning model_calls into v_global;

  if v_global >= (v_limits ->> 'global_daily_calls')::int then
    return jsonb_build_object('allowed', false, 'reason', 'at_capacity');
  end if;

  -- R10.1 fair use, above every tier.
  insert into public.usage_hourly (user_id, hour, calls)
  values (p_user_id, v_hour, 0)
  on conflict (user_id, hour) do update set calls = public.usage_hourly.calls
  returning calls into v_hourly;

  if v_hourly >= (v_limits ->> 'hourly_calls')::int then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'rate_limited',
      'retry_after_seconds',
      greatest(1, extract(epoch from (v_hour + interval '1 hour' - now()))::int)
    );
  end if;

  insert into public.usage_daily (user_id, day, messages)
  values (p_user_id, current_date, 0)
  on conflict (user_id, day) do update set messages = public.usage_daily.messages
  returning messages into v_messages;

  if v_messages >= v_daily_limit then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'quota_exceeded',
      'tier', v_tier,
      'used', v_messages,
      'daily_limit', v_daily_limit,
      'resets_at', v_resets,
      -- R8.3 and §16: offering an upgrade that does not lift the ceiling is a
      -- dark pattern. A Pro user at the fair-use ceiling gets told to wait.
      'upgradeable', v_tier = 'free'
    );
  end if;

  -- Allowed. Record all three counters now, before the model is called.
  update public.usage_daily
     set messages = messages + 1
   where user_id = p_user_id and day = current_date;

  update public.usage_hourly
     set calls = calls + 1
   where user_id = p_user_id and hour = v_hour;

  update public.usage_global
     set model_calls = model_calls + 1
   where day = current_date;

  -- Opportunistic cleanup, cheap because of usage_hourly_hour_idx. Without it
  -- the table grows by one row per active user per hour forever, on a free
  -- tier with a 500MB ceiling.
  delete from public.usage_hourly where hour < now() - interval '2 hours';

  return jsonb_build_object(
    'allowed', true,
    'tier', v_tier,
    'used', v_messages + 1,
    'daily_limit', v_daily_limit,
    'resets_at', v_resets,
    'kind', p_kind
  );
end;
$$;

comment on function public.consume_model_call(uuid, text) is
  'R9.3.1 steps 2-4 and R9.3.4, as one atomic statement. Increments before the '
  'model call on purpose: a crash must not be free usage.';

-- Only the gateway may call this. `authenticated` calling it directly would be
-- able to burn its own quota, which is harmless, but it would also learn the
-- exact ceilings — and there is no reason for the path to exist at all.
revoke all on function public.consume_model_call(uuid, text) from public, anon, authenticated;

-- ── Built-in partners ship as data (§5.3.2) ──────────────────────────────────
--
-- "Built-in partners ship as data, not code, so they can be edited without a
-- release." Five of them, which is exactly what §8 gives a free user.
--
-- Fixed UUIDs so this migration is idempotent and so a thread's partner_id
-- survives a re-seed. None of these prompts carry the crisis instruction;
-- gateway_config.safety_preamble is prepended to every one of them at request
-- time, so it cannot be forgotten here.

insert into public.partners (
  id, owner_id, name, description, system_prompt,
  voice_rate, voice_pitch, difficulty, locale, is_builtin, visibility
) values
  (
    '11111111-1111-4111-8111-000000000001', null,
    'Free Talk',
    'Talk about anything. No scoring, no agenda.',
    'Have an ordinary conversation. Follow their lead on topic. Ask one '
    'genuine follow-up question per turn so there is always something to '
    'answer. Do not coach, correct, or grade unless they ask.',
    1.0, 1.0, 1, 'en', true, 'public'
  ),
  (
    '11111111-1111-4111-8111-000000000002', null,
    'Interviewer',
    'A job interview. Answer, then get asked why.',
    'Conduct a job interview. Ask one question at a time and wait. Follow up '
    'on vague answers by asking for a specific example. Stay neutral and '
    'professional; do not reassure them mid-interview. If they gave a goal '
    'such as a role or a company, tailor the questions to it. At the end, if '
    'they ask how they did, be direct and specific about two things.',
    1.0, 1.0, 3, 'en', true, 'public'
  ),
  (
    '11111111-1111-4111-8111-000000000003', null,
    'Conversation Partner',
    'Everyday English at a pace you choose.',
    'Practise everyday spoken English. Keep your own sentences simple and '
    'clear. Speak at the level they speak at, one step above. When they use a '
    'word wrongly, use the right word naturally in your reply rather than '
    'correcting them outright, and only correct explicitly if the meaning was '
    'lost.',
    1.0, 1.0, 2, 'en', true, 'public'
  ),
  (
    '11111111-1111-4111-8111-000000000004', null,
    'Presentation Coach',
    'Rehearse out loud. Get told what landed.',
    'They are rehearsing a talk or a pitch. Let them speak in long stretches '
    'and do not interrupt. When they pause, respond as an attentive audience: '
    'say what you understood, then name one thing that was unclear. Ask about '
    'structure and evidence, not delivery mechanics — the app measures those '
    'itself.',
    1.0, 1.0, 3, 'en', true, 'public'
  ),
  (
    '11111111-1111-4111-8111-000000000005', null,
    'Debate Opponent',
    'Pick a side. Defend it under pressure.',
    'Take the opposite side of whatever position they state, and argue it '
    'honestly and well. Attack the reasoning, never the person. Concede a '
    'point when they actually make one — an opponent who never concedes '
    'teaches nothing. Keep each turn to one clear objection so they can answer '
    'it.',
    1.0, 1.0, 4, 'en', true, 'public'
  )
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  system_prompt = excluded.system_prompt,
  voice_rate = excluded.voice_rate,
  voice_pitch = excluded.voice_pitch,
  difficulty = excluded.difficulty,
  visibility = excluded.visibility;
