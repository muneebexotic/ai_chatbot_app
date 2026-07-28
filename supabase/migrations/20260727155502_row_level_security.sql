-- Row Level Security — PRD R9.5.1.
--
-- The rule: a user can read and write only their own rows. `partners` adds a
-- public-read policy for `visibility = 'public'`. `entitlements` and
-- `usage_daily` are service-role write only — the client reads its own row and
-- can never write one.
--
-- ## How this is enforced
--
-- The `service_role` key bypasses RLS entirely, so "service-role write only"
-- is expressed by writing NO insert/update/delete policy for the `authenticated`
-- role. RLS denies by default: a table with RLS enabled and no matching policy
-- rejects the statement. The absence of a policy IS the control, which is why
-- each such table carries a comment saying so — a future reader must not
-- "fix" the apparent omission by adding one.
--
-- Policies are written per-command rather than as `for all`, so that read and
-- write can differ per table without rewriting anything.
--
-- `(select auth.uid())` rather than bare `auth.uid()`: the subquery form is
-- evaluated once per statement instead of once per row, which matters on the
-- list queries in §11's performance budget.

-- ── profiles ─────────────────────────────────────────────────────────────────
-- Own row only. No delete policy: account deletion runs under service role
-- through the Edge Function in R9.5.2, so a client cannot orphan its own auth
-- user by deleting the profile directly.

alter table public.profiles enable row level security;

create policy "profiles: read own"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "profiles: insert own"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "profiles: update own"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- ── entitlements ─────────────────────────────────────────────────────────────
-- SERVICE-ROLE WRITE ONLY (R9.5.1, PRD F2). Read-own is the only policy that
-- may exist on this table. Do not add insert/update/delete policies: an
-- entitlement the client can write is an entitlement the client can grant
-- itself, which is the entire subscription bypassed.

alter table public.entitlements enable row level security;

create policy "entitlements: read own"
  on public.entitlements for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- ── usage_daily ──────────────────────────────────────────────────────────────
-- SERVICE-ROLE WRITE ONLY (R9.5.1). Same reasoning: a client that can write
-- its usage row can reset it, and the free tier becomes unlimited. The gateway
-- writes this atomically with the response it accounts for (R9.3.4).

alter table public.usage_daily enable row level security;

create policy "usage_daily: read own"
  on public.usage_daily for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- ── partners ─────────────────────────────────────────────────────────────────
-- Own rows, plus public read for `visibility = 'public'` — which is what makes
-- the built-ins (owner_id null, is_builtin true) readable by everyone.
--
-- The write policies deliberately pin `owner_id` to the caller and forbid
-- `is_builtin`, so a user cannot mint a partner that impersonates a shipped
-- one. Promotion to `public` is a review step (§6) performed under service
-- role, not something the owner does to itself; `with check` on update blocks
-- the self-promotion path.

alter table public.partners enable row level security;

create policy "partners: read own"
  on public.partners for select
  to authenticated
  using ((select auth.uid()) = owner_id);

create policy "partners: read public"
  on public.partners for select
  to authenticated, anon
  using (visibility = 'public');

create policy "partners: insert own"
  on public.partners for insert
  to authenticated
  with check (
    (select auth.uid()) = owner_id
    and is_builtin = false
    and visibility in ('private', 'pending')
  );

create policy "partners: update own"
  on public.partners for update
  to authenticated
  using ((select auth.uid()) = owner_id)
  with check (
    (select auth.uid()) = owner_id
    and is_builtin = false
    and visibility in ('private', 'pending')
  );

create policy "partners: delete own"
  on public.partners for delete
  to authenticated
  using ((select auth.uid()) = owner_id);

-- ── threads ──────────────────────────────────────────────────────────────────

alter table public.threads enable row level security;

create policy "threads: read own"
  on public.threads for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "threads: insert own"
  on public.threads for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "threads: update own"
  on public.threads for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "threads: delete own"
  on public.threads for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ── messages ─────────────────────────────────────────────────────────────────
-- `messages` has no `user_id` (§9.5), so ownership is reached through the
-- parent thread. Every policy is an EXISTS against `threads`, which is why
-- `messages_thread_id_idx` and the threads primary key both matter here.

alter table public.messages enable row level security;

create policy "messages: read own"
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
        and t.user_id = (select auth.uid())
    )
  );

create policy "messages: insert own"
  on public.messages for insert
  to authenticated
  with check (
    exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
        and t.user_id = (select auth.uid())
    )
  );

create policy "messages: update own"
  on public.messages for update
  to authenticated
  using (
    exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
        and t.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
        and t.user_id = (select auth.uid())
    )
  );

create policy "messages: delete own"
  on public.messages for delete
  to authenticated
  using (
    exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
        and t.user_id = (select auth.uid())
    )
  );

-- ── sessions ─────────────────────────────────────────────────────────────────

alter table public.sessions enable row level security;

create policy "sessions: read own"
  on public.sessions for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "sessions: insert own"
  on public.sessions for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "sessions: update own"
  on public.sessions for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "sessions: delete own"
  on public.sessions for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ── memories ─────────────────────────────────────────────────────────────────
-- Write policies exist so the user can delete a memory from the Memory screen
-- (§5.2) — the ability to forget is a privacy requirement, not a convenience.

alter table public.memories enable row level security;

create policy "memories: read own"
  on public.memories for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "memories: insert own"
  on public.memories for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "memories: update own"
  on public.memories for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "memories: delete own"
  on public.memories for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ── referrals ────────────────────────────────────────────────────────────────
-- Readable by either party. Writes are service-role only: the reward state
-- machine in §6 pays out, and a client that can write its own referral rows
-- can pay itself.

alter table public.referrals enable row level security;

create policy "referrals: read own"
  on public.referrals for select
  to authenticated
  using (
    (select auth.uid()) = inviter_id
    or (select auth.uid()) = invitee_id
  );

-- ── abuse_events ─────────────────────────────────────────────────────────────
-- SERVICE-ROLE WRITE ONLY, and deliberately not readable by the user either.
--
-- R9.5.1 names only `entitlements` and `usage_daily` as service-role write, and
-- its general rule is that a user reads and writes their own rows. Applying
-- that literally here would let a user forge, edit, or delete the record of
-- their own abuse, which defeats §10 entirely. Read access is withheld as well
-- because the detail column describes what the detector looks for, and handing
-- that to the party being detected is free reconnaissance.
--
-- This is a deliberate reading of R9.5.1 rather than an omission — recorded in
-- DECISIONS.md D7.

alter table public.abuse_events enable row level security;
