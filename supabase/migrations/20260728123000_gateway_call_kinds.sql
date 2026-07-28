-- `consume_model_call` distinguishes the message the user asked for from the
-- calls the server makes on their behalf.
--
-- A separate migration rather than an edit to 20260728120000, because that one
-- is already applied to kalaam-dev and R9.2.2 makes the committed files the
-- schema's history. Rewriting an applied migration means the file and the
-- database describe different things, which is exactly the drift the
-- requirement exists to prevent.
--
-- ## What was wrong
--
-- The first version took `p_kind` and did nothing with it but echo it back, so
-- generating a thread title — a call the user never requested — spent one of
-- their 30 free daily messages. That is a quota the product charges for its
-- own housekeeping, and it would have been invisible: the user sees 29 left
-- after sending one message and has no way to learn why.
--
-- ## The rule now
--
-- Every call, whatever its kind, counts against R10.4's global ceiling and
-- R10.1's hourly fair-use limit — those exist to protect a shared free quota
-- and a title consumes that quota exactly as much as a reply does.
--
-- Only `kind = 'message'` counts against the user's daily allowance, because
-- that is the one they chose to spend.

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
  v_billable boolean := p_kind = 'message';
  v_resets timestamptz := (date_trunc('day', now() at time zone 'utc') + interval '1 day')
                          at time zone 'utc';
begin
  select value into v_limits from public.gateway_config where key = 'limits';
  if v_limits is null then
    -- Fail closed. A missing config row is a deployment error, and the safe
    -- reading of "I do not know the limit" is "no".
    return jsonb_build_object('allowed', false, 'reason', 'misconfigured');
  end if;

  insert into public.entitlements (user_id, tier, state)
  values (p_user_id, 'free', 'active')
  on conflict (user_id) do nothing;

  select tier, state, expires_at into v_tier, v_state, v_expires
  from public.entitlements where user_id = p_user_id;

  -- An expired or cancelled Pro row is a free user. §8.2 requires handling
  -- grace, hold, cancellation, and refund revocation, and each of those leaves
  -- `tier` reading 'pro' for a while.
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
  -- reported to them as their own quota.
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

  if v_billable and v_messages >= v_daily_limit then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'quota_exceeded',
      'tier', v_tier,
      'used', v_messages,
      'daily_limit', v_daily_limit,
      'resets_at', v_resets,
      -- R8.3 and §16: offering an upgrade that does not lift the ceiling is a
      -- dark pattern. A Pro user at the fair-use ceiling is told to wait.
      'upgradeable', v_tier = 'free'
    );
  end if;

  -- Allowed. Record before the model is called, never after: a crash must not
  -- be free usage (R9.3.4).
  if v_billable then
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

  -- Opportunistic cleanup, a range scan thanks to usage_hourly_hour_idx.
  -- Without it the table grows by one row per active user per hour forever,
  -- on a free tier with a 500MB ceiling.
  delete from public.usage_hourly where hour < now() - interval '2 hours';

  return jsonb_build_object(
    'allowed', true,
    'tier', v_tier,
    'used', v_messages,
    'daily_limit', v_daily_limit,
    'resets_at', v_resets,
    'kind', p_kind,
    'billable', v_billable
  );
end;
$$;

revoke all on function public.consume_model_call(uuid, text) from public, anon, authenticated;
