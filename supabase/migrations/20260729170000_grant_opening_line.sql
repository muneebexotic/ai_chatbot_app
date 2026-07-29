-- Grant the column the previous migration added.
--
-- `20260729160000_partner_opening_line.sql` added `partners.opening_line` and
-- the client started selecting it. On a device the partner rail came back EMPTY
-- and "Start speaking" was disabled — the whole product unreachable.
--
-- ## Why adding a column silently revoked it
--
-- Milestone 3's `20260728140000_partners_column_privileges.sql` runs:
--
--     revoke select (system_prompt) on public.partners from authenticated, anon;
--
-- A **column-level** revoke cannot subtract from a table-level grant, so
-- Postgres does the only thing it can: it drops the table-wide `SELECT` and
-- replaces it with an explicit per-column grant for every column that remains.
--
-- That is invisible and permanent. From that migration onward this table has no
-- table-level SELECT privilege, so **every column added later starts with no
-- grant at all** and is unreadable by `authenticated` until one is written.
-- Nothing in the schema says so; `\dp partners` shows a column list where a
-- table grant used to be, and only if you know to look.
--
-- ## Why the client's fallback did not catch it
--
-- The repository already tolerates a missing column, but it matches `42703`
-- (undefined_column). A column that exists and is not granted returns `42501`
-- (insufficient_privilege) instead, so the query failed outright. That is fixed
-- alongside this — but the grant is the real fix, and the fallback is the seat
-- belt.
--
-- ## The rule this establishes
--
-- Any future migration that adds a column to `partners` MUST grant it
-- explicitly, in the same migration. There is no table-level grant to inherit.

grant select (opening_line) on public.partners to authenticated, anon;

comment on column public.partners.opening_line is
  'R4.1.3''s example opening line, shown on the brief screen. Written FOR the '
  'user to read, unlike system_prompt. NOTE: partners has no table-level SELECT '
  'grant since the Milestone 3 column revoke — any column added here needs its '
  'own `grant select (col)` or it is invisible to clients.';
