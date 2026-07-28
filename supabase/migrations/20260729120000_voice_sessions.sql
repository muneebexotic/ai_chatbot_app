-- Server-side voice metering — PRD §8, R10.1, F2, R9.3.4.
--
-- Milestone 3 built `consume_model_call`, which counts messages. §9.5's
-- `usage_daily.voice_seconds` column has existed since the initial schema and
-- nothing has ever written to it, so §8's "10 minutes per day" of spoken
-- Sessions was unenforced and unenforceable.
--
-- ## Why a spoken turn must not spend a typed message
--
-- §8 gives a free user 30 typed messages per day AND 10 minutes of spoken
-- Sessions. A ten-minute session is roughly twenty exchanges. If each spoken
-- turn decremented `usage_daily.messages`, the session would end at message 30
-- with a "you are out of messages" error — and the user would have lost their
-- typed allowance to a feature that was supposed to have its own. The two
-- budgets are separate in the PRD and are separate here: `consume_model_call`
-- now takes a kind, and 'voice' charges seconds instead of messages while
-- still passing every R10.1 fair-use and R10.4 circuit-breaker check.
--
-- ## Why the meter is wall-clock and server-side (F2)
--
-- The obvious design is for the client to report how long it spoke. That is
-- exactly the defect F2 names: "Entitlements and quotas MUST be computed and
-- enforced server-side; the client only *displays* them." A patched APK that
-- reports zero seconds would have unlimited voice.
--
-- So nothing here trusts a client-supplied duration. A session row carries
-- `last_metered_at`, and every meter call charges `now() - last_metered_at`
-- measured by the database clock. The client cannot make time pass more slowly.
--
-- §8 says "10 minutes per day" of Sessions, which is session wall-clock, not
-- seconds-of-detected-speech — and wall-clock is the thing a server can measure
-- without trusting anybody.
--
-- ## Why the charge is clamped
--
-- A force-killed session (R4.2.6) leaves a row that is `open` with a
-- `last_metered_at` in the past. Without a clamp, a user who crashed at 09:00
-- and returned at 17:00 would be billed eight hours. `max_meter_seconds`
-- bounds any single charge, so the worst case is one heartbeat interval of
-- over-charge rather than a day's quota. Being wrong in the user's favour is
-- the correct direction here, which is the opposite of the direction
-- `consume_model_call` chose for messages — and for the same reason. There,
-- being generous rewards an attacker who can cause crashes. Here, the attacker
-- gains at most one clamp per crash while an honest user would lose their whole
-- day.
--
-- ## Why under-reporting by not calling the meter does not work
--
-- A client could simply stop sending heartbeats. It cannot stop the gateway:
-- every model turn inside a session meters before it answers, so a session that
-- avoids the meter is a session with no AI in it — which is not a model-backed
-- session at all. Heartbeats only cover the gaps between turns.

-- ── Session lifecycle state ──────────────────────────────────────────────────

create type public.session_state as enum ('open', 'ended', 'abandoned');

alter table public.sessions
  add column state public.session_state not null default 'ended',
  add column last_metered_at timestamptz,
  add column metered_seconds integer not null default 0
    check (metered_seconds >= 0);

comment on column public.sessions.state is
  'open while metering, ended when closed normally, abandoned when swept after '
  'a force-kill (R4.2.6). An abandoned session still has its transcript and '
  'still produces a report — abandoned describes the metering, not the data.';

comment on column public.sessions.last_metered_at is
  'Server clock, never a client value. The meter charges now() - this.';

comment on column public.sessions.metered_seconds is
  'What this session actually charged against usage_daily.voice_seconds. Kept '
  'per session so a support question about a day s usage can be answered.';

-- One open session per user. A second one would meter twice against the same
-- wall clock, and there is no legitimate way to speak in two at once.
create unique index sessions_one_open_per_user
  on public.sessions (user_id)
  where state = 'open';

-- ── Limits ───────────────────────────────────────────────────────────────────

update public.gateway_config
set value = value
  || jsonb_build_object(
       'free_daily_voice_seconds', 600,
       'pro_daily_voice_seconds', 14400,
       'max_meter_seconds', 90
     ),
    description =
      'free_daily_messages and free_daily_voice_seconds are §8 (30 typed, 10 '
      'spoken minutes). pro_daily_voice_seconds is R10.1 s "max 4 hours of '
      'voice per day", which sits ABOVE Pro "unlimited" as a fair-use ceiling. '
      'pro_daily_messages and hourly_calls are the same idea for text. '
      'global_daily_calls is R10.4 s circuit breaker. max_meter_seconds bounds '
      'a single meter charge so a force-killed session cannot bill the gap.'
where key = 'limits';

-- ── Opening a session ────────────────────────────────────────────────────────

create or replace function public.open_voice_session(
  p_user_id uuid,
  p_partner_id uuid,
  p_thread_id uuid default null,
  p_goal text default null
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
  v_limit int;
  v_used int;
  v_session uuid;
  v_resets timestamptz := (date_trunc('day', now() at time zone 'utc') + interval '1 day')
                          at time zone 'utc';
begin
  select value into v_limits from public.gateway_config where key = 'limits';
  if v_limits is null then
    -- Fail closed, same as consume_model_call: "I do not know the limit"
    -- reads as "no".
    return jsonb_build_object('allowed', false, 'reason', 'misconfigured');
  end if;

  -- Sweep anything this user left open. A force-kill (R4.2.6) never reaches a
  -- close, so this is the normal path after a crash, not an exceptional one.
  perform public.sweep_open_sessions(p_user_id);

  select tier, state, expires_at into v_tier, v_state, v_expires
  from public.entitlements where user_id = p_user_id;

  if v_tier is null then
    insert into public.entitlements (user_id, tier, state)
    values (p_user_id, 'free', 'active')
    on conflict (user_id) do nothing;
    v_tier := 'free';
  end if;

  -- Same demotion rule as consume_model_call: an expired or cancelled Pro row
  -- is a free user. §8.2 requires grace, hold, cancellation and refund
  -- revocation to be handled, and each leaves `tier` saying 'pro' for a while.
  if v_tier = 'pro'
     and (v_state not in ('active', 'grace')
          or (v_expires is not null and v_expires < now())) then
    v_tier := 'free';
  end if;

  v_limit := case v_tier
    when 'pro' then (v_limits ->> 'pro_daily_voice_seconds')::int
    else (v_limits ->> 'free_daily_voice_seconds')::int
  end;

  insert into public.usage_daily (user_id, day, voice_seconds)
  values (p_user_id, current_date, 0)
  on conflict (user_id, day) do update set voice_seconds = public.usage_daily.voice_seconds
  returning voice_seconds into v_used;

  if v_used >= v_limit then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'quota_exceeded',
      'tier', v_tier,
      'used_seconds', v_used,
      'daily_limit_seconds', v_limit,
      'resets_at', v_resets,
      -- R8.3, §16: never offer an upgrade that would not lift the ceiling. A
      -- Pro user at R10.1's four-hour fair-use limit is told to wait.
      'upgradeable', v_tier = 'free'
    );
  end if;

  insert into public.sessions (
    user_id, partner_id, thread_id, goal, started_at, last_metered_at, state
  )
  values (p_user_id, p_partner_id, p_thread_id, p_goal, now(), now(), 'open')
  returning id into v_session;

  return jsonb_build_object(
    'allowed', true,
    'session_id', v_session,
    'tier', v_tier,
    'used_seconds', v_used,
    'daily_limit_seconds', v_limit,
    'remaining_seconds', greatest(0, v_limit - v_used),
    'resets_at', v_resets
  );
end;
$$;

-- ── Metering ─────────────────────────────────────────────────────────────────

create or replace function public.meter_voice_session(
  p_user_id uuid,
  p_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limits jsonb;
  v_last timestamptz;
  v_state public.session_state;
  v_delta int;
  v_clamp int;
  v_tier public.entitlement_tier;
  v_ent_state public.entitlement_state;
  v_expires timestamptz;
  v_limit int;
  v_used int;
  v_resets timestamptz := (date_trunc('day', now() at time zone 'utc') + interval '1 day')
                          at time zone 'utc';
begin
  select value into v_limits from public.gateway_config where key = 'limits';
  if v_limits is null then
    return jsonb_build_object('allowed', false, 'reason', 'misconfigured');
  end if;

  -- `for update` is the lock that makes read-modify-write safe here. Two
  -- concurrent meters — a heartbeat and a gateway turn arriving together — must
  -- not both charge from the same last_metered_at.
  select last_metered_at, state into v_last, v_state
  from public.sessions
  where id = p_session_id and user_id = p_user_id
  for update;

  if v_last is null then
    -- No such session, or not this caller's. A uuid in a request body is a
    -- claim, not a permission.
    return jsonb_build_object('allowed', false, 'reason', 'not_found');
  end if;

  if v_state <> 'open' then
    return jsonb_build_object('allowed', false, 'reason', 'not_open');
  end if;

  v_clamp := (v_limits ->> 'max_meter_seconds')::int;
  v_delta := least(greatest(0, extract(epoch from (now() - v_last))::int), v_clamp);

  update public.sessions
     set last_metered_at = now(),
         metered_seconds = metered_seconds + v_delta
   where id = p_session_id;

  insert into public.usage_daily (user_id, day, voice_seconds)
  values (p_user_id, current_date, v_delta)
  on conflict (user_id, day) do update
    set voice_seconds = public.usage_daily.voice_seconds + v_delta
  returning voice_seconds into v_used;

  select tier, state, expires_at into v_tier, v_ent_state, v_expires
  from public.entitlements where user_id = p_user_id;

  if v_tier = 'pro'
     and (v_ent_state not in ('active', 'grace')
          or (v_expires is not null and v_expires < now())) then
    v_tier := 'free';
  end if;

  v_limit := case coalesce(v_tier, 'free')
    when 'pro' then (v_limits ->> 'pro_daily_voice_seconds')::int
    else (v_limits ->> 'free_daily_voice_seconds')::int
  end;

  -- Note what this does NOT do: it does not close the session. R8.3 is explicit
  -- that a free user hitting the cap mid-session must "never [be cut] off
  -- mid-sentence, finish the exchange, then show it". The server reports that
  -- the allowance is gone and the client finishes the current exchange before
  -- ending. The seconds are already charged either way, so nothing is given
  -- away by being civil about it.
  return jsonb_build_object(
    'allowed', v_used < v_limit,
    'reason', case when v_used < v_limit then null else 'quota_exceeded' end,
    'tier', coalesce(v_tier, 'free'),
    'charged_seconds', v_delta,
    'used_seconds', v_used,
    'daily_limit_seconds', v_limit,
    'remaining_seconds', greatest(0, v_limit - v_used),
    'resets_at', v_resets,
    'upgradeable', coalesce(v_tier, 'free') = 'free'
  );
end;
$$;

-- ── Closing ──────────────────────────────────────────────────────────────────
--
-- `p_duration_seconds` and `p_metrics` come from the client and are stored, not
-- trusted. They are the report's contents (R4.3.1 computes them on the device
-- by design, so the report works offline and with no model call). Nothing about
-- quota reads them: `metered_seconds` is what was charged, and it is computed
-- here. A client that lies about its metrics gets a wrong report card, which is
-- its own problem; it does not get free minutes.

create or replace function public.close_voice_session(
  p_user_id uuid,
  p_session_id uuid,
  p_duration_seconds int default null,
  p_metrics jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meter jsonb;
begin
  v_meter := public.meter_voice_session(p_user_id, p_session_id);

  update public.sessions
     set state = 'ended',
         ended_at = now(),
         duration_seconds = coalesce(p_duration_seconds, duration_seconds),
         metrics = coalesce(p_metrics, metrics)
   where id = p_session_id and user_id = p_user_id;

  if not found then
    return jsonb_build_object('closed', false, 'reason', 'not_found');
  end if;

  return jsonb_build_object('closed', true, 'usage', v_meter);
end;
$$;

-- ── Sweeping a force-killed session (R4.2.6) ─────────────────────────────────
--
-- "A session that is force-killed MUST still produce a report from whatever
-- transcript was persisted." The transcript is local (§9.4); this is the
-- server-side half — the row stops metering and is marked abandoned so it does
-- not block the next session's unique index.

create or replace function public.sweep_open_sessions(p_user_id uuid)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
  v_swept int := 0;
begin
  for v_row in
    select id from public.sessions
    where user_id = p_user_id and state = 'open'
    for update
  loop
    -- Charge the final clamped slice, then abandon it. Skipping the charge
    -- would make force-killing the app a way to get free minutes.
    perform public.meter_voice_session(p_user_id, v_row.id);

    update public.sessions
       set state = 'abandoned',
           ended_at = coalesce(ended_at, last_metered_at)
     where id = v_row.id;

    v_swept := v_swept + 1;
  end loop;

  return v_swept;
end;
$$;

-- ── consume_model_call learns about voice ────────────────────────────────────
--
-- A spoken turn still passes R10.1 hourly fair use and R10.4's global circuit
-- breaker — those are about protecting a shared free quota and apply to every
-- model call regardless of where it came from. What it does NOT do is spend a
-- typed message.

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
  v_is_voice boolean := p_kind = 'voice';
  v_resets timestamptz := (date_trunc('day', now() at time zone 'utc') + interval '1 day')
                          at time zone 'utc';
begin
  select value into v_limits from public.gateway_config where key = 'limits';
  if v_limits is null then
    return jsonb_build_object('allowed', false, 'reason', 'misconfigured');
  end if;

  insert into public.entitlements (user_id, tier, state)
  values (p_user_id, 'free', 'active')
  on conflict (user_id) do nothing;

  select tier, state, expires_at into v_tier, v_state, v_expires
  from public.entitlements where user_id = p_user_id;

  if v_tier = 'pro'
     and (v_state not in ('active', 'grace')
          or (v_expires is not null and v_expires < now())) then
    v_tier := 'free';
  end if;

  v_daily_limit := case v_tier
    when 'pro' then (v_limits ->> 'pro_daily_messages')::int
    else (v_limits ->> 'free_daily_messages')::int
  end;

  insert into public.usage_global (day, model_calls)
  values (current_date, 0)
  on conflict (day) do update set model_calls = public.usage_global.model_calls
  returning model_calls into v_global;

  if v_global >= (v_limits ->> 'global_daily_calls')::int then
    return jsonb_build_object('allowed', false, 'reason', 'at_capacity');
  end if;

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

  -- The one branch this migration adds. A spoken turn is metered in seconds by
  -- meter_voice_session and must not also spend one of the day's 30 messages.
  if not v_is_voice and v_messages >= v_daily_limit then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'quota_exceeded',
      'tier', v_tier,
      'used', v_messages,
      'daily_limit', v_daily_limit,
      'resets_at', v_resets,
      'upgradeable', v_tier = 'free'
    );
  end if;

  if not v_is_voice then
    update public.usage_daily
       set messages = messages + 1
     where user_id = p_user_id and day = current_date;
    v_messages := v_messages + 1;
  end if;

  update public.usage_hourly
     set calls = calls + 1
   where user_id = p_user_id and hour = v_hour;

  update public.usage_global
     set model_calls = model_calls + 1
   where day = current_date;

  delete from public.usage_hourly where hour < now() - interval '2 hours';

  return jsonb_build_object(
    'allowed', true,
    'tier', v_tier,
    'used', v_messages,
    'daily_limit', v_daily_limit,
    'resets_at', v_resets,
    'kind', p_kind
  );
end;
$$;

-- Same lockdown as consume_model_call (Milestone 3): only the gateway and the
-- session function, both under service role, may call these. A client that
-- could call meter_voice_session directly could choose when its own clock runs.
revoke all on function public.open_voice_session(uuid, uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.meter_voice_session(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.close_voice_session(uuid, uuid, int, jsonb)
  from public, anon, authenticated;
revoke all on function public.sweep_open_sessions(uuid)
  from public, anon, authenticated;

comment on function public.meter_voice_session(uuid, uuid) is
  'F2 and §8: charges wall-clock seconds measured by the database, never a '
  'client-reported duration. Clamped by limits.max_meter_seconds so a '
  'force-killed session cannot bill the gap until the user returns.';
