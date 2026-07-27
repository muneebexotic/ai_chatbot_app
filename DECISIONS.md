# DECISIONS.md

Architectural and product decisions that deviate from, amend, or interpret the
PRD. Required by PRD §0.3 (SHOULD-level deviations), R12.1, R12.2, and R9.3.6.

Newest first. Every entry records what changed, why, what it costs, and what
would reverse it.

---

## D3 — Default model routing moves off Gemini's unpaid tier

**Date:** 2026-07-26 · **Status:** approved · **Amends:** PRD R9.3.3 ·
**Adds:** R9.3.6

**Was:** "Default to a fast, low-cost Gemini model on its free tier, and keep
the routing layer provider-agnostic."

**Now:** live conversational turns → **Groq**; reports and memory extraction →
**Groq or Cerebras**; vision → Gemini only, if §5.4 ships at all. The
provider-agnostic requirement is unchanged and now load-bearing.

**Why.** `RESEARCH.md` §4.B, from primary sources:

- Gemini's **unpaid** tier: "Google uses the content you submit to the Services
  and any generated responses to provide, improve, and develop Google products
  and services and machine learning technologies"; "human reviewers may read,
  annotate, and process your API input and output"; "Do not submit sensitive,
  confidential, or personal information to the Unpaid Services."
- Gemini's terms also state: "You may use only Paid Services when making API
  Clients available to users in the European Economic Area, Switzerland, or the
  United Kingdom." This is an **availability** restriction on the developer,
  distinct from the data carve-out that gives EEA users paid-tier protections.
  The two are easy to confuse and only one of them was seen on the first pass.
- **Groq**, Services Agreement, applying at every tier with no free/paid
  distinction: "Groq is not permitted to use Inputs or Outputs for training or
  fine-tuning any AI Model Services or other models, unless explicitly granted
  permission."
- Groq is also the fastest free option (~700+ tokens/sec), which is the best
  available route to R4.2.4's sub-1.5s latency budget.

A session transcript is the most personal artefact this app produces. Sending
it to a tier whose terms explicitly say not to send personal information, while
R4.2.7 advertises privacy as a selling point, is a conflict the product cannot
carry.

**Cost:** none. Groq and Cerebras are card-free.

**Open risk:** the Cerebras position is graded **[C]** in `RESEARCH.md` — not
verified against the primary EULA. R9.3.6 now requires reading a provider's
terms in full before wiring it in. **Cerebras must not carry transcripts until
that read is done and logged here.**

**Reverses if:** Groq's terms change, or the §12.1 revenue trigger is crossed
and Gemini's paid tier (which does not train on prompts) becomes affordable.

---

## D2 — Drill Mode becomes the free tier; Sessions become premium

**Date:** 2026-07-26 · **Status:** approved · **Amends:** PRD §8 ·
**Adds:** R8.0, R8.0.1 · **Implements:** `PROPOSALS.md` P2

**Was:** free = 10 minutes of spoken Sessions per day. Sessions were the only
practice surface, and the free tier was a smaller portion of the paid one.

**Now:** free users live in **Drill Mode** — spoken practice scored entirely
on-device, unlimited forever — with 10 minutes/day of model-backed Sessions on
top as a taste. Sessions are the premium surface.

**Why.** Three reasons, in order of weight:

1. **A free user must never cost money to serve.** This is the invariant that
   survives the D1 amendment. Drill Mode has no model call, so it has no
   marginal cost and no breach point at any user count (R12.2.2).
2. **Free usage cannot be hostage to a third party's quota.** `RESEARCH.md`
   §4.A puts the single-provider breach point at ~8–48 DAU. A free tier built
   on model calls stops working before the product has a hundred users.
3. **Free usage sends nothing to anyone.** Per D3, this removes the free tier
   from the provider-terms problem entirely.

There is also a competitive argument: ELSA's unlimited free pronunciation
drills are the main reason a free user picks ELSA over a conversation app
(`RESEARCH.md` §5.5). Drill Mode answers that at zero cost.

**Cost:** 6–8 developer days, mostly content design. The metrics engine is
already floor work (R4.3.1).

**Risk, stated plainly:** Drill Mode is launch-critical but scheduled last, at
Milestone 5, because it depends on the R4.3.1 metrics engine from Milestone 4.
Mitigation: build that engine as a standalone, independently testable module
with Drill Mode as a known consumer, and treat a Milestone 4 slip as a threat
to launch rather than to one milestone.

**Reverses if:** user testing shows drills without a conversational partner do
not build a habit. That would be a serious finding — it would mean the free
tier has no zero-cost form, and the D1 trigger would need to arrive much
earlier.

---

## D1 — The zero-cost rule becomes zero-cost-**before-revenue**

**Date:** 2026-07-26 · **Status:** approved by owner · **Amends:** PRD §0.5
rule 5, §0.5.2, §16 · **Adds:** §12.1

**Was:** "Every service used MUST be on a free tier that requires no credit
card." No exceptions. The only permitted cost was Play registration.

**Now:** free tiers only **until subscription revenue exists to pay for
anything else**. After the §12.1 trigger, paid services are permitted where
funded by revenue already received.

**Two invariants survive and are not negotiable:**

1. **The free tier stays permanently zero-marginal-cost** — guaranteed
   structurally by D2, not by policy.
2. **No spend precedes revenue.** The trigger is a floor, not a forecast.

**The trigger:** 100 active paying subscribers, sustained one complete billing
month. Arithmetic in R12.1.2, with the one unsourced input — paid inference
cost per session — flagged as an estimate that must be recalculated against
real provider pricing and measured token counts before any spend.

**Why.** The original rule was written on the assumption that free model tiers
could carry the product. `RESEARCH.md` §4 shows they cannot, on two independent
grounds:

- **Capacity** (§4.A): breach at ~8–48 DAU single-provider, ~60–100 DAU with
  the P1 router. Google cut free quotas 50–80% without notice on 2025-12-07 and
  no longer publishes the numbers.
- **Terms** (§4.B): the unpaid tier trains on user content, permits human
  review, and bars serving the EEA/Switzerland/UK.

An absolute zero-cost rule would therefore require either abandoning
model-backed Sessions or shipping a privacy claim that is misleading. Neither
is acceptable. Tying spend to revenue keeps the owner's actual constraint — **no
money up front** — fully intact while removing an artificial ceiling on the
product.

**What crossing the trigger buys, beyond capacity** (R12.1.4):

1. **It ends third-party training on user transcripts.** Gemini's paid tier
   does not use prompts or responses to improve Google's products.
2. **It unblocks Europe**, which the unpaid terms forbid serving.

Both are product and ethics wins, not just capacity wins. That is the strongest
argument for the amendment: the paid tier is *more* aligned with §16 than the
free one.

**Cost:** nothing up front. By construction.

**Guardrail:** R12.1.3 — never authorise more than 33% of trailing-month net
revenue in monthly spend, and hold three months of projected inference cost
before enabling billing anywhere.

**Reverses if:** revenue never reaches the trigger. In that case the product
stays permanently on free tiers with Drill Mode as the whole free experience
and Sessions capped hard — which is a viable, if smaller, product. **That is
the point of D2: the fallback is a real product, not a failure state.**

---

## D0 — Firebase rejected, then removed by force

**Date:** 2026-07-25, updated 2026-07-26 · **Status:** settled ·
**Records:** PRD R12.3.1

Firebase was rejected in the PRD because Cloud Storage and Cloud Functions
require a linked billing account, breaking the then-absolute zero-cost rule.
Recorded here so the choice is not silently reversed.

**Update, 2026-07-26:** the question became moot. Google suspended the Firebase
project `ai-chatbot-app-22e84` for "abusive activity consistent with hijacking"
after credentials committed to the public repo were harvested and used
(`SECURITY-REMEDIATION.md`). Impact was zero — no billing account was ever
linked and there were no real users — but the project is abandoned rather than
appealed, since PRD §2.2 already scheduled its removal.

**Consequence:** Milestone 2 is *build Supabase from scratch*, not *migrate off
Firebase*. Less work, and no dual-write period.
