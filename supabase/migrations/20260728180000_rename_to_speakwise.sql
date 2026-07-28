-- The app is called SpeakWise (DECISIONS D9, PRD §17.1).
--
-- One row changes: `gateway_config.safety_preamble` opens by telling the model
-- what app it is speaking for, and it said "Kalaam". That string is **shipped
-- into every prompt**, which makes it the one place a stale product name could
-- reach a user in the model's own voice — a partner introducing itself by the
-- old name, or referring to it mid-conversation.
--
-- A migration rather than an edit to 20260728120000, for the reason R9.2.2
-- exists: the earlier file is applied to kalaam-dev, and the committed
-- migrations are the schema's history rather than a description of its current
-- state. Rewriting an applied file makes the two disagree.
--
-- No function redeploy is needed. The gateway reads this row per request, which
-- is exactly what R9.3.3 wanted from putting configuration in the database:
-- changing what the model is told is a migration, not a release.
--
-- ## What is deliberately NOT renamed
--
-- The Supabase projects stay `kalaam` and `kalaam-dev`. A project's name is a
-- dashboard label; the refs (`kneiwapwjuuaxcenlfsu`, `sbwaiindthrluqoypvqc`)
-- are what every URL, key, and migration actually resolves against, and those
-- cannot change. Renaming the projects would cost a round of confusion for
-- readers of this repo and buy nothing.
--
-- The comment header on 20260727155452 also still says "Kalaam initial schema".
-- Left alone on purpose: it is a historical file describing what was written on
-- 2026-07-27, under the name the project had that day.

update public.gateway_config
   set value = to_jsonb(
     replace(value #>> '{}', 'in Kalaam,', 'in SpeakWise,')
   )
 where key = 'safety_preamble';

-- Fail loudly if the string it targets ever moves. A silent no-op here would
-- leave the model introducing itself by a name the app no longer uses, and
-- nothing else in the system would notice.
do $$
begin
  if not exists (
    select 1 from public.gateway_config
     where key = 'safety_preamble'
       and value #>> '{}' like '%in SpeakWise,%'
  ) then
    raise exception
      'safety_preamble was not updated — the phrase it matched on has moved. '
      'Check gateway_config before assuming this migration ran.';
  end if;
end $$;
