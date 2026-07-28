-- Kalaam initial schema — PRD §9.5.
--
-- Every table here is named in §9.5 and carries the columns it specifies.
-- RLS is enabled per table in the next migration; nothing in this file grants
-- access, and no table is reachable by a client until that migration runs.
--
-- Conventions:
--   * `timestamptz`, never `timestamp`. The app is used across timezones and a
--     naive timestamp silently means "whatever the server thought local was".
--   * Enums are real Postgres types rather than text + CHECK, so an invalid
--     value is rejected by the database instead of by whoever remembers.
--   * Every foreign key is indexed. Postgres indexes the primary key but not
--     the referencing side, and every list in this app filters by one.

-- ── Enum types ───────────────────────────────────────────────────────────────

create type public.entitlement_tier as enum ('free', 'pro');

create type public.entitlement_state as enum (
  'active', 'grace', 'hold', 'cancelled', 'expired'
);

create type public.partner_visibility as enum ('private', 'pending', 'public');

create type public.message_role as enum ('user', 'assistant');

create type public.referral_state as enum (
  'pending', 'accepted', 'rewarded', 'expired'
);

-- ── Shared trigger: keep `updated_at` honest ─────────────────────────────────
--
-- Set by the database rather than the client, because a client clock is not
-- evidence of anything and §9.4 syncs last-write-wins on a server timestamp.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ── profiles ─────────────────────────────────────────────────────────────────
--
-- One row per auth user. `deleted_at` supports R9.5.2's anonymise-in-place
-- path: rows that must survive for referential integrity are stripped of
-- personal data and tombstoned rather than deleted outright.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  locale text not null default 'en',
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on column public.profiles.deleted_at is
  'Account deletion tombstone (R9.5.2). Non-null means the row is anonymised.';

-- Create the profile when the auth user appears, so no code path can leave a
-- signed-in user without one.
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
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── entitlements ─────────────────────────────────────────────────────────────
--
-- Server truth (PRD F2). The client displays this and never writes it; the
-- write restriction is enforced in the RLS migration, not here.

create table public.entitlements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tier public.entitlement_tier not null default 'free',
  source text,
  expires_at timestamptz,
  play_purchase_token text,
  play_order_id text,
  state public.entitlement_state not null default 'active',
  updated_at timestamptz not null default now()
);

-- Purchase tokens are unique per purchase; a second row claiming the same one
-- is either a bug or a replay attempt. The database is the right place to say
-- no, since §8 verifies purchases server-side against the Play API.
create unique index entitlements_play_purchase_token_key
  on public.entitlements (play_purchase_token)
  where play_purchase_token is not null;

create trigger entitlements_set_updated_at
  before update on public.entitlements
  for each row execute function public.set_updated_at();

-- ── usage_daily ──────────────────────────────────────────────────────────────
--
-- The quota ledger. Written only by the gateway (§9.3) under service role, and
-- atomically with the response it accounts for (R9.3.4).

create table public.usage_daily (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null default current_date,
  voice_seconds integer not null default 0 check (voice_seconds >= 0),
  messages integer not null default 0 check (messages >= 0),
  images integer not null default 0 check (images >= 0),
  primary key (user_id, day)
);

-- ── partners ─────────────────────────────────────────────────────────────────
--
-- `owner_id` is null for the built-ins that ship with the app. Those are
-- `is_builtin` and `public`, which is what makes them readable by everyone
-- under the public-read policy in the next migration.

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users (id) on delete cascade,
  name text not null,
  description text,
  system_prompt text not null,
  voice_rate real not null default 1.0,
  voice_pitch real not null default 1.0,
  difficulty smallint not null default 2 check (difficulty between 1 and 5),
  locale text not null default 'en',
  is_builtin boolean not null default false,
  visibility public.partner_visibility not null default 'private',
  use_count integer not null default 0 check (use_count >= 0),
  created_at timestamptz not null default now(),
  -- A built-in has no owner; anything else must have one. Without this, an
  -- ownerless user-made partner would be invisible to its creator and
  -- unreachable by every policy in the next migration.
  constraint partners_builtin_has_no_owner check (
    (is_builtin and owner_id is null) or (not is_builtin and owner_id is not null)
  )
);

create index partners_owner_id_idx on public.partners (owner_id);
create index partners_visibility_idx on public.partners (visibility)
  where visibility = 'public';

-- ── threads ──────────────────────────────────────────────────────────────────

create table public.threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  partner_id uuid references public.partners (id) on delete set null,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index threads_user_id_idx on public.threads (user_id, updated_at desc);
create index threads_partner_id_idx on public.threads (partner_id);

create trigger threads_set_updated_at
  before update on public.threads
  for each row execute function public.set_updated_at();

-- ── messages ─────────────────────────────────────────────────────────────────
--
-- There is deliberately no `user_id` here — §9.5 does not specify one, and
-- ownership is derived through `thread_id`. That makes the RLS policy a join
-- rather than a column comparison; see the next migration.

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads (id) on delete cascade,
  role public.message_role not null,
  content text not null,
  created_at timestamptz not null default now()
);

create index messages_thread_id_idx on public.messages (thread_id, created_at);

-- ── sessions ─────────────────────────────────────────────────────────────────
--
-- The flagship record (§4). `metrics` and `report` are jsonb because their
-- shape is still being designed in Milestones 4 and 5; they become real
-- columns only when something needs to query inside them.
--
-- There is no audio column, and there will not be one: §16 forbids storing
-- session audio.

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  thread_id uuid references public.threads (id) on delete set null,
  partner_id uuid references public.partners (id) on delete set null,
  goal text,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_seconds integer check (duration_seconds >= 0),
  metrics jsonb,
  report jsonb,
  created_at timestamptz not null default now()
);

create index sessions_user_id_idx on public.sessions (user_id, started_at desc);
create index sessions_thread_id_idx on public.sessions (thread_id);
create index sessions_partner_id_idx on public.sessions (partner_id);

-- ── memories ─────────────────────────────────────────────────────────────────
--
-- R5.2.4 forbids storing sensitive categories here — health, religion,
-- politics, sexual orientation, finances, government ID, exact addresses,
-- third parties. That is a filter in the extraction function (Milestone 3),
-- not something the database can express, and it is written here so nobody
-- concludes from the schema alone that anything goes.

create table public.memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  content text not null,
  source_session_id uuid references public.sessions (id) on delete set null,
  created_at timestamptz not null default now()
);

create index memories_user_id_idx on public.memories (user_id, created_at desc);
create index memories_source_session_id_idx on public.memories (source_session_id);

-- ── referrals ────────────────────────────────────────────────────────────────

create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references auth.users (id) on delete cascade,
  invitee_id uuid references auth.users (id) on delete set null,
  state public.referral_state not null default 'pending',
  created_at timestamptz not null default now(),
  constraint referrals_no_self_invite check (inviter_id is distinct from invitee_id)
);

create index referrals_inviter_id_idx on public.referrals (inviter_id);
create index referrals_invitee_id_idx on public.referrals (invitee_id);

-- An invitee can be referred once. Enforced here rather than in application
-- code because §6 pays out on it.
create unique index referrals_invitee_id_key
  on public.referrals (invitee_id)
  where invitee_id is not null;

-- ── abuse_events ─────────────────────────────────────────────────────────────
--
-- The audit trail behind §10. Written by the gateway under service role.
-- `user_id` is nullable and `on delete set null` so deleting an account does
-- not erase the evidence that led to a block (R9.5.2 anonymises; it does not
-- hand out a clean slate).

create table public.abuse_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  kind text not null,
  detail jsonb,
  created_at timestamptz not null default now()
);

create index abuse_events_user_id_idx on public.abuse_events (user_id, created_at desc);
