-- The free memory ceiling — PRD §8.
--
-- "Memory | Free: 10 items | Pro: Unlimited".
--
-- Added as its own migration for the reason given in 20260728123000: the
-- earlier files are applied to kalaam-dev, and R9.2.2 makes the committed
-- migrations the schema's history rather than a description of its current
-- state. Editing an applied file makes the two disagree.
--
-- It lives in `limits` with the other ceilings so there is exactly one row to
-- read when someone asks "what are the numbers", and so changing it never
-- needs an app release (R9.3.3's reasoning, applied to a quota rather than to
-- a model).
--
-- `extract-memory` enforces it. F2 puts entitlement on the server, and a cap
-- the client applies is a cap a patched client does not apply.

update public.gateway_config
   set value = jsonb_set(value, '{free_memory_items}', '10'::jsonb)
 where key = 'limits';
