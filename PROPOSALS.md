# PROPOSALS.md

Required by PRD R0.5.2. Ten candidate additions beyond the floor, ranked.
Compiled 2026-07-26, from findings in `RESEARCH.md`.

**Nothing here gets built without the owner's approval (R0.5.3).** Floor first,
always (R0.5.4).

The loop being strengthened, from PRD §3:
**speak → report → weak spot → return tomorrow → hit the free cap → subscribe.**

Differentiation is scored /10 against the apps in `RESEARCH.md` — Speak, ELSA,
TalkPal, Yoodli, Praktika, Loora, Replika, Character.AI. A 10 means no
competitor does it. A 3 means everyone does it and we would be catching up.

Effort is solo-developer days, including tests.

---

## Ranked

| # | Proposal | Loop stage | Effort | Cost risk | Diff. |
|---|---|---|---|---|---|
| **P1** | Multi-provider model router | all — unblocks the product | 4–6d | **Removes** the largest risk | 6 |
| **P2** | Drill Mode — zero model calls | speak, return, free cap | 6–8d | **Zero.** Fully local | 9 |
| **P3** | Memory as a headline feature | return, subscribe | 3–4d | Negligible | 9 |
| **P4** | "Beat your last session" report opener | weak spot → return | 2–3d | Zero — local | 7 |
| **P5** | Clarity score from recognizer confidence | report, subscribe | 3–5d | Zero — local | 8 |
| **P6** | Live filler nudge during a session | speak → weak spot | 4–5d | Zero — local | 8 |
| **P7** | Interview mode from a pasted job description | speak, subscribe | 3–4d | Low (one call) | 7 |
| **P8** | Noisy-room fallback to typing, mid-session | speak | 2–3d | Zero | 6 |
| **P9** | 30-day before/after share card | growth | 3–4d | Zero — local | 6 |
| **P10** | Partner "warm open" from memory | speak, return | 1–2d | Zero (prompt only) | 5 |

---

## Recommended: P1, P2, P3

Build these three, in this order, and skip or defer the rest. P1 is survival,
P2 is the moat, P3 is the cheapest win in the document.

A list that recommends everything recommends nothing, so to be explicit about
what I am arguing *against*: **P9 and P10 are not worth v1.** P9 needs 30 days
of user history before it can render anything, which means it cannot help
launch. P10 is a two-line prompt change dressed up as a feature. Do them later
or never. **P4, P5, P6 are strong but they are all report polish** — they
compete with each other for the same slot, and P5 is the one I would keep.

---

### P1 — Multi-provider model router · Milestone 3 · **BUILD FIRST**

**What it is.** Instead of defaulting to Gemini and treating other providers as
a later swap, the gateway fans out across Gemini + Groq + Cerebras from day one,
routing by job: live conversational turns to Groq (fastest free option
available), reports and memory extraction to Gemini or Cerebras, vision to
Gemini. Each provider's free quota is independent, so capacity is additive
rather than capped by the weakest link.

**Loop.** All of it. Without this there is no loop, because there is no capacity
to run one.

**Effort.** 4–6 days. Most of it is a clean provider interface, per-provider
quota accounting, and failover tests — not per-provider glue.

**Cost and free-tier risk.** This is the mitigation, not the risk.
`RESEARCH.md` §4.2 puts the single-provider breach point at roughly **8–48
daily active users**, one to two orders of magnitude below the 1,000 DAU the
PRD expects to plan for. Every provider involved is card-free, so §0.5.2's
zero-cost ceiling is respected.

**Differentiation: 6.** Users never see it. Scored on what it enables, not on
novelty — a competitor could copy it, but most funded competitors simply pay
and never need to.

**Why first.** This is the only item on the list that is not optional. PRD
R9.3.3 already requires provider-agnostic routing; this is the difference
between honouring that requirement and merely satisfying it. Also note it
partly de-risks itself: Groq at 700+ tokens/sec is the best shot at the
R4.2.4 sub-1.5-second latency budget, which is the hardest number in the PRD.

---

### P2 — Drill Mode: practice that costs nothing · Milestone 5 · **THE MOAT**

**What it is.** A practice mode with **no model call at all**: the app shows a
passage, a prompt, or a question; the user speaks; every metric in R4.3.1 —
pace, fillers, pauses, vocabulary variety, longest unbroken stretch — is
computed on-device from the transcript. Same Waveform, same report layout, same
design language as a full Session, but the marginal cost is exactly zero.

**Loop.** Strengthens three stages at once. It gives free users a genuine daily
habit (return), it produces a weak spot without spending quota, and it makes
hitting the spoken-session cap feel like hitting a *premium* ceiling rather
than a wall — the user still has something to do today.

**Effort.** 6–8 days, and most of it is content design rather than engineering,
because the metrics engine is already floor work in R4.3.1.

**Cost and free-tier risk.** **Zero, permanently, at any scale.** No network
call. Works offline. This is the only feature proposed that has no breach point.

**Differentiation: 9.** ELSA's free tier — unlimited pronunciation drills — is
described in `RESEARCH.md` §5.4 as genuinely the best free tool in the
category, and it is the main reason a free user picks ELSA over a conversation
app. Drill Mode is the answer to that at zero cost, in Kalaam's design
language, on the metrics Kalaam already computes.

**Why it matters more than it looks.** `RESEARCH.md` §4 means the model-backed
Session is capacity-limited for the foreseeable future. Drill Mode is the part
of the product that scales to a million users on a free tier. That inverts the
usual risk: the viral day that would exhaust the quota lands mostly on the
feature that has no quota.

---

### P3 — Memory as a headline feature · Milestone 3 · **CHEAPEST WIN HERE**

**What it is.** Take the Memory screen the PRD already requires (R5.2.2) and
promote it from a settings page to a product claim: a real moment in
onboarding where the user watches the app remember something and is shown they
can edit or delete it, a visible "remembers you" surface on the partner brief
screen, and it becomes a primary line in the store listing.

**Loop.** Return and subscribe. A partner that references last week's goal is
the reason day 8 happens.

**Effort.** 3–4 days. The storage, the extraction, and the screen are all floor
work already. This is placement, copy, one onboarding beat, and store assets.

**Cost and free-tier risk.** Negligible — extraction is already budgeted at
one call per session, and P1 gives it somewhere cheap to run.

**Differentiation: 9.** `RESEARCH.md` §1.4: memory is the loudest complaint in
the companion category and it is not close. Replika users report their
companion forgetting within days; Character.AI effectively has no long-term
memory at all. Meanwhile nobody in the language-practice set exposes memory as
editable. The PRD calls this "a trust feature and a differentiator" — the
research says it is the top unmet need in the adjacent category, which is a
stronger claim than the PRD makes for it.

**One caution.** R5.2.4's forbidden categories become more load-bearing the
more visible memory is. The deny-instruction and the server-side filter must
both ship before this is promoted, and the filter needs its own tests.

---

## The rest, briefly

**P4 — "Beat your last session" opener** · M5 · 2–3d · zero cost · **7/10**
The report leads with one direct comparison against the previous session on the
user's weakest metric, e.g. "4.1 fillers/min, down from 6.8." Turns a static
report into a rematch. Must obey R4.3.5: an invitation, never a punishment, and
never a guilt frame on a bad day.

**P5 — Clarity score from recognizer confidence** · M5 · 3–5d · zero cost ·
**8/10**
`speech_to_text` returns per-result confidence. Aggregated across a session it
is a usable proxy for how clearly the user was speaking — computed locally, for
free. This is a cheap flank on ELSA's paid pronunciation scoring. **Risk worth
naming:** confidence is a recognizer artefact, not a phonetic judgment, and
`RESEARCH.md` C2 shows users react badly to scores they think are wrong. Ship
it as "how clearly the recognizer heard you," never as a pronunciation grade,
or it becomes the complaint instead of the feature.

**P6 — Live filler nudge** · M4 · 4–5d · zero cost · **8/10**
A subtle Waveform tint when filler-word rate spikes over the last 30 seconds —
no sound, no text, no interruption. Yoodli does this on desktop during
Zoom/Meet calls; nobody does it phone-native. Must be off by default and must
respect reduce-motion (R7.7.4). Genuine risk of feeling like surveillance; test
before committing.

**P7 — Interview mode from a job description** · M4/M5 · 3–4d · low · **7/10**
User pastes a JD; the Interviewer partner generates role-specific questions.
Sharpens the highest-intent, highest-willingness-to-pay segment. Adds one model
call per session setup and needs prompt-injection handling, since pasted text
is hostile input under R9.3.2.

**P8 — Noisy-room fallback to typing** · M4 · 2–3d · zero cost · **6/10**
R4.2.2 already requires detecting a noisy environment and suggesting push-to-
talk. This adds a third option: keep the session, switch to typing, keep the
transcript and the report. Directly answers complaint cluster C2 — recognition
failing in noise is the top functional complaint in the category — and §5.1
already requires spoken and typed threads to be the same thread, so the
plumbing exists.

**P9 — 30-day before/after share card** · M7 · 3–4d · zero cost · **6/10**
Progress comparison card rather than a single-session card. Better shareable
than P6.1's version, but **it cannot help at launch** — it needs 30 days of
history to render anything. Defer.

**P10 — Partner "warm open" from memory** · M3 · 1–2d · zero cost · **5/10**
The partner opens by referencing the last session instead of a generic
greeting. Cheap and nice, but R5.2.3 arguably requires it already. Included for
completeness; treat as polish under R0.5.1, not a feature.

---

## What I deliberately did not propose

- **Streak mechanics beyond PRD floor.** `RESEARCH.md` §1.4 — Replika took a
  €5M GDPR fine and a 67-page FTC complaint alleging engineered emotional
  dependence. §16 bans guilt-based streaks. That is a closed ceiling and the
  regulatory weather is moving toward the PRD, not away from it.
- **Leaderboards or social comparison.** Competitive speaking metrics against
  strangers would harm the anxious second-language user who is the primary
  buyer.
- **Cloud speech recognition**, even where quality would improve. It breaks
  R4.2.7 (audio never leaves the device), breaks the zero-marginal-cost
  advantage that `RESEARCH.md` §5.2 shows is the whole business model, and
  breaks the privacy claim in one move.
- **Anything needing a paid tier or a linked card.** §0.5.2.
