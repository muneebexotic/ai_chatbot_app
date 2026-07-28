-- `partners.system_prompt` is genuinely unreadable by a client this time.
--
-- ## What was wrong with 20260728120000
--
-- That migration ended with:
--
--     revoke select (system_prompt) on public.partners from authenticated, anon;
--
-- which ran without error, appeared in the migration history, and did nothing.
-- A column-level REVOKE cannot subtract from a table-level GRANT: in Postgres,
-- `GRANT SELECT ON table` means every column, present and future, and the
-- column-level privilege system is only consulted when the table-level
-- privilege is absent. Supabase grants table-level SELECT to `anon` and
-- `authenticated` by default, so the revoke had nothing to act on.
--
-- Verified against kalaam-dev the only way that counts — by asking for the
-- column as a signed-in user:
--
--     GET /rest/v1/partners?select=*  ->  200, system_prompt included
--
-- This is the exact shape of CRITIQUE.md W2.1: a control that reads correctly,
-- passes review, and does not hold. It was found by making the request rather
-- than by reading the SQL back.
--
-- ## The correct form
--
-- Remove the table-level grant, then grant back column by column. The
-- consequence is deliberate and loud: `select=*` now fails for a client
-- instead of quietly returning one column too many, so a repository that
-- forgets to name its columns breaks immediately and visibly.
--
-- ## Why the column is worth this trouble
--
-- R9.3.2 makes the prompt server-decided. §6.2 will let users publish partners
-- for review, at which point this column holds user-authored text that other
-- users could read before a human has approved it. And a partner prompt in the
-- client's hands is the first half of working out how to talk around it.

revoke select on public.partners from authenticated, anon;

grant select (
  id,
  owner_id,
  name,
  description,
  voice_rate,
  voice_pitch,
  difficulty,
  locale,
  is_builtin,
  visibility,
  use_count,
  created_at
) on public.partners to authenticated, anon;

-- Writes are unchanged and still filtered by the RLS policies from Milestone 2
-- ("partners: insert own" / "update own" pin owner_id to the caller and forbid
-- is_builtin). A user creating a custom partner (§5.3.2) must be able to write
-- its prompt, so `system_prompt` stays writable — it is reading someone else's
-- that is closed.
grant insert (
  id, owner_id, name, description, system_prompt,
  voice_rate, voice_pitch, difficulty, locale, visibility
) on public.partners to authenticated;

grant update (
  name, description, system_prompt,
  voice_rate, voice_pitch, difficulty, locale, visibility
) on public.partners to authenticated;

grant delete on public.partners to authenticated;

comment on column public.partners.system_prompt is
  'Not readable by anon or authenticated — see 20260728140000. Writable by a '
  'partner owner so custom partners work (§5.3.2). The gateway reads it under '
  'service role, which is the only path that should ever need it.';
