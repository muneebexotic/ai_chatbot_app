# PROPOSALS.md

Required by PRD R0.5.2. Ten candidates beyond the floor, ranked.
Compiled 2026-07-26, from findings in `RESEARCH.md`. **Revised 2026-07-26**
after owner review — see the changelog at the end.

**Status: P1, P2, P3 and P8 are APPROVED by the owner.** P4, P6, P7, P9, P10
remain proposals. P5 is withdrawn.

The loop being strengthened, from PRD §3:
**speak → report → weak spot → return tomorrow → hit the free cap → subscribe.**

Differentiation is scored /10 against the apps in `RESEARCH.md`. A 10 means no
competitor does it; a 3 means we would be catching up. Effort is solo-developer
days, including tests.

---

## Ranked

| # | Proposal | Status | Loop stage | Effort | Cost risk | Diff. |
|---|---|---|---|---|---|---|
| **P2** | **Drill Mode — the free tier** | **APPROVED · launch-critical** | speak, return, free cap | 6–8d | **Zero, permanently** | 9 |
| **P1** | Multi-provider router | **APPROVED** | latency + runway | 4–6d | Extends runway ~2–3× | 6 |
| **P3** | Memory as a headline feature | **APPROVED** | return, subscribe | 3–4d | Negligible | 9 |
| **P8** | Noisy-room fallback to typing | **APPROVED** (swapped in for P5) | speak | 2–3d | Zero | 6 |
| P4 | "Beat your last session" opener | proposed | weak spot → return | 2–3d | Zero — local | 7 |
| P6 | Live filler nudge | proposed | speak → weak spot | 4–5d | Zero — local | 8 |
| P7 | Interview mode from a job description | proposed | speak, subscribe | 3–4d | Low | 7 |
| P9 | 30-day before/after share card | proposed — defer | growth | 3–4d | Zero | 6 |
| P10 | Partner "warm open" from memory | proposed — polish only | speak, return | 1–2d | Zero | 5 |
| ~~P5~~ | ~~Clarity score from recognizer confidence~~ | **WITHDRAWN** | — | — | — | — |

**Build order** (chronological, since milestones differ from priority):
P1 → P3 (both Milestone 3) → P8 (Milestone 4) → P2 (Milestone 5).

P2 ranks first by importance and last by schedule. That is uncomfortable and
worth stating plainly: **the most important approved item ships last**, because
it depends on the R4.3.1 metrics engine built in Milestone 4. It must not be
allowed to slip further — see P2.

---

### P2 — Drill Mode: this is the free tier · Milestone 5 · **LAUNCH-CRITICAL**

**What it is.** A practice mode with **no model call at all**: the app shows a
passage, a prompt, or a question; the user speaks; every metric in R4.3.1 —
pace, fillers, pauses, vocabulary variety, longest unbroken stretch — is
computed on-device from the transcript. Same Waveform, same report layout, same
design language as a full Session, at exactly zero marginal cost.

**This is not a bonus feature. It is where free users live.** Per owner
direction, §8 is restructured so that Drill Mode is the free tier's default
home, with a small daily allowance of model-backed Sessions on top; Sessions
become the premium surface rather than the baseline one. The PRD amendment is
logged in `DECISIONS.md` (D2).

**Loop.** Three stages at once. It gives free users a real daily habit
(return), produces a weak spot without spending quota, and turns the Session
cap from a wall into a ceiling — the user always has something to do today.

**Effort.** 6–8 days, mostly content design. The metrics engine is already
floor work in R4.3.1.

**Cost and free-tier risk.** **Zero, permanently, at any scale.** No network
call, works offline, no provider terms apply because no content leaves the
device. That last point matters more than it looks given `RESEARCH.md` §4.B:
Drill Mode is the only part of the product with no third-party data exposure at
all.

**Differentiation: 9.** ELSA's unlimited free pronunciation drills are the main
reason a free user picks ELSA over a conversation app (`RESEARCH.md` §5.5).
Drill Mode answers that at zero cost, in Kalaam's design language, on metrics
Kalaam already computes.

**Why it carries the business.** `RESEARCH.md` §4 means model-backed Sessions
are capacity-limited *and* terms-constrained for the foreseeable future. Drill
Mode is the only part of the product that scales to a million users on a free
tier. That inverts the usual risk: a viral day lands mostly on the feature with
no quota and no data exposure.

**Schedule risk, stated plainly.** Being launch-critical and last is the main
delivery risk in the plan. Two mitigations: build the R4.3.1 metrics engine in
Milestone 4 as a standalone, independently testable module with Drill Mode as a
known consumer, and treat any slip in Milestone 4 as a slip that threatens
launch, not merely Milestone 5.

---

### P1 — Multi-provider model router · Milestone 3 · **BUILD FIRST**

**What it is.** The gateway routes across Gemini + Groq + Cerebras by job:
live conversational turns to Groq, reports and memory extraction to Groq or
Cerebras, vision to Gemini if image understanding ships at all.

**What it is NOT — corrected after owner review.** The first version of this
document claimed P1 "removes the largest risk". **That was wrong, and it was
wrong using this document's own numbers.** Three independent free tiers do not
multiply capacity threefold in practice, because the limits differ in kind
(Groq counts requests, Cerebras counts tokens), because one provider must still
absorb the latency-critical path, and because failover only helps until the
fallback is also exhausted. Realistically it buys **~2–3×**, moving the breach
point from ~8–48 DAU to roughly **60–100 DAU**. That is a runway extender, not
a scaling fix, and the difference matters: at 100 DAU the product still needs a
funding answer, which is what `DECISIONS.md` D1 provides.

**What it actually buys, honestly:**

1. **Latency.** Groq at 700+ tokens/sec is the best available shot at R4.2.4's
   sub-1.5-second budget — the hardest number in the PRD. This alone justifies
   the work.
2. **Terms.** Per `RESEARCH.md` §4.B, Groq is contractually barred from
   training on inputs or outputs at *every* tier, and Cerebras reportedly
   retains nothing. Gemini's unpaid tier trains on submitted content, permits
   human review, and cannot lawfully serve the EEA/CH/UK. Routing away from
   Gemini is the privacy-correct choice, not merely the fast one.
3. **Runway.** ~2–3×, per above.
4. **Optionality.** When revenue crosses the D1 trigger, switching a route to a
   paid tier becomes a config change rather than a migration.

**Loop.** Indirect. It does not strengthen a stage; it keeps the model-backed
stages working at all, and makes the "speak" stage fast enough to feel like
conversation.

**Effort.** 4–6 days: a clean provider interface, per-provider quota
accounting, and failover tests. Not per-provider glue.

**Cost and free-tier risk.** Every provider involved is card-free, so §0.5.2's
zero-cost ceiling is respected as amended by D1.

**Differentiation: 6.** Users never see it. Scored on what it enables.

---

### P3 — Memory as a headline feature · Milestone 3 · **APPROVED AS WRITTEN**

**What it is.** Promote the Memory screen the PRD already requires (R5.2.2)
from a settings page to a product claim: a real onboarding beat where the user
watches the app remember something and is shown they can edit or delete it, a
visible "remembers you" surface on the partner brief screen, and a primary line
in the store listing.

**Loop.** Return and subscribe. A partner that references last week's goal is
the reason day 8 happens.

**Effort.** 3–4 days. Storage, extraction, and the screen are floor work
already. This is placement, copy, one onboarding beat, and store assets.

**Cost and free-tier risk.** Negligible.

**Differentiation: 9.** `RESEARCH.md` §1.4: memory is the loudest complaint in
the companion category and it is not close. Replika forgets within days;
Character.AI effectively has no long-term memory. Nobody in the
language-practice set exposes memory as editable.

**Hard gate, per owner direction.** **The R5.2.4 filter and its tests ship
before memory is promoted anywhere user-facing.** Not the same milestone —
*before*. The deny-instruction in the extraction prompt and the server-side
keyword filter both need passing tests covering every forbidden category
(health, religion, politics, sexual orientation, finances, government ID, exact
addresses, third parties). Promoting a memory feature that can capture a
health condition would convert the single best differentiator into the single
worst liability.

`RESEARCH.md` §4.B sharpens this: on a provider that trains on submitted
content, a leaked sensitive fact does not merely land in our database, it lands
in someone's training set. The filter must run **before** the extraction call,
not after it.

---

### P8 — Noisy-room fallback to typing · Milestone 4 · **APPROVED (swapped in)**

**What it is.** R4.2.2 already requires detecting a noisy environment and
suggesting push-to-talk. This adds a third option: keep the session, switch to
typing, keep the transcript and the report intact.

**Loop.** Speak. It rescues sessions that currently end in abandonment.

**Effort.** 2–3 days. §5.1 already requires spoken and typed conversations to
share one thread, so the plumbing exists.

**Cost and free-tier risk.** Zero.

**Differentiation: 6.** Modest score, high value-per-day-of-work. It answers
complaint cluster C2 — recognition failing in noise is the top *functional*
complaint across the whole category (`RESEARCH.md` §1.3) — and it answers it
better than the incumbents, who leave the user stuck.

**Why it replaced P5.** Cheaper, lower-risk, and aimed at the same complaint
cluster from the opposite direction: P5 tried to *score* the user better in bad
conditions, P8 lets them keep working in bad conditions. The second is more
useful and cannot backfire.

---

## Still proposals — not approved

**P4 — "Beat your last session" opener** · M5 · 2–3d · zero cost · **7/10**
The report leads with one comparison against the previous session on the user's
weakest metric, e.g. "4.1 fillers/min, down from 6.8." Turns a static report
into a rematch. Must obey R4.3.5: an invitation, never a punishment, and never
a guilt frame on a bad day.

**P6 — Live filler nudge** · M4 · 4–5d · zero cost · **8/10**
A subtle Waveform tint when filler rate spikes over the last 30 seconds — no
sound, no text, no interruption. Yoodli does this on desktop during
Zoom/Meet/Teams calls; nobody does it phone-native. Must be off by default and
respect reduce-motion (R7.7.4). Real risk of feeling like surveillance; test
before committing.

**P7 — Interview mode from a job description** · M4/M5 · 3–4d · low · **7/10**
User pastes a JD; the Interviewer partner generates role-specific questions.
Sharpens the highest-intent, highest-willingness-to-pay segment. Adds a model
call per session setup and needs prompt-injection handling, since pasted text
is hostile input under R9.3.2.

**P9 — 30-day before/after share card** · M7 · 3–4d · zero cost · **6/10**
Cannot help at launch — needs 30 days of history to render anything. Defer.

**P10 — Partner "warm open" from memory** · M3 · 1–2d · zero cost · **5/10**
R5.2.3 arguably requires it already. Treat as polish under R0.5.1, not a
feature.

---

## Withdrawn

**P5 — Clarity score from recognizer confidence.** Withdrawn 2026-07-26 by
owner decision, in favour of P8. The reasoning holds up: `speech_to_text`
confidence is a recognizer artefact, not a phonetic judgment, and
`RESEARCH.md` C2 shows users react badly to scores they believe are wrong —
including both over-strict scoring and the opposite failure of rating obvious
mispronunciation as excellent. Shipping a "clarity score" that is really a
signal-quality readout invites exactly the complaint that damaged ELSA. P8
addresses the same conditions without ever grading the user.

---

## What I deliberately did not propose

- **Streak mechanics beyond PRD floor.** `RESEARCH.md` §1.4 — Replika took a
  €5M GDPR fine and a 67-page FTC complaint alleging engineered emotional
  dependence. §16 bans guilt-based streaks; the regulatory weather is moving
  toward the PRD, not away from it.
- **Leaderboards or social comparison.** Competitive metrics against strangers
  would harm the anxious second-language user who is the primary buyer.
- **Cloud speech recognition**, even where quality would improve. It breaks
  R4.2.7, destroys the zero-marginal-cost advantage that `RESEARCH.md` §5.3
  shows is the whole business model, and — given §4.B — would hand the rawest
  possible personal data to a third party. Three violations in one decision.
- **Anything needing a paid tier or a linked card before revenue exists.**
  §0.5.2 as amended by `DECISIONS.md` D1.

---

## Changelog

**2026-07-26 — owner review.**
- P1 **approved, reframed**. The "removes the largest risk" claim was wrong and
  is corrected: ~2–3×, breach point ~60–100 DAU, a latency play and runway
  extender rather than a scaling fix. Groq for live turns confirmed.
- P2 **approved and promoted** from third to first. Drill Mode is the free
  tier, not a bonus. §8 restructured accordingly (`DECISIONS.md` D2). Stays at
  Milestone 5 on dependency grounds but is treated as launch-critical.
- P3 **approved as written**, with a hard gate: R5.2.4 filter and tests ship
  before any user-facing promotion of memory.
- P5 **withdrawn**, P8 **approved** in its place.
- Owner identified a finding this document missed entirely: the Gemini unpaid
  tier's terms (training on content, human review, EEA/CH/UK restriction). Now
  `RESEARCH.md` §4.B, and it materially strengthens the case for P1's routing
  away from Gemini.
