# RESEARCH.md

Required by PRD R0.5.1, before Milestone 1. Compiled 2026-07-26. All sources
accessed that date.

## How to read this, and how much to trust it

Source quality varies a lot and pretending otherwise would be worse than
useless, so every claim below is graded:

- **[A]** primary source — the vendor's own docs, the store listing, or a
  regulator/court filing.
- **[B]** established review platform with volume — Trustpilot, G2, Capterra,
  Product Hunt.
- **[C]** secondary blog, comparison site, or SEO content. A great deal of the
  "best AI speaking app 2026" web is affiliate-driven and copies itself.
  Treated as a signal of consensus, never as fact.

Where sources disagree, that is reported as disagreement rather than averaged
into a false number. Nothing here is invented; where I could not get a figure,
it says so.

**The single most important finding is §4. It contradicts a load-bearing
assumption in the PRD and should be read before anything else.**

---

## 1. Competitor teardown

### 1.1 The field

| App | Positioning | Price (2026) | Free tier | Rating |
|---|---|---|---|---|
| **Speak** | Conversation practice, 15+ languages, OpenAI-backed | ~$20/mo **[C]** | Limited daily reps | 4.70★, 110–112K ratings, 15M+ downloads **[C]** |
| **ELSA Speak** | Pronunciation / accent, phoneme-level | ~$11.99/mo; $99.99–$127.99/yr **[C]** | Unlimited pronunciation drills — genuinely strong **[C]** | **4.9★ Play** vs **2.5/5 Trustpilot** **[B]** |
| **TalkPal** | AI language tutor, ~35 languages | ~$6–18/mo; $90/yr **[C]** | Generous daily AI conversation **[C]** | 4.3★ **[C]** |
| **Yoodli** | Speech/interview coach with analytics — *closest to Kalaam* | Pro $8/mo annual; Advanced $20/mo **[C]** | **5 lifetime sessions** | 4.7★ G2, small pool **[B]** |
| **Praktika** | AI avatar tutors | not reliably sourced | trial-based | mixed; see 1.3 **[B]** |
| **Loora** | Business English, premium positioning | most expensive of the set **[C]** | trial-based | 4.9★ **[C]** |
| **Replika** | AI companion | Pro $19.99/mo **[C]** | limited | see 1.4 |
| **Character.AI** | AI companion | subscription | generous | see 1.4 |

### 1.2 The rating gap that matters most

**ELSA Speak: 4.9★ on Google Play, 2.5/5 "Poor" on Trustpilot [B].**

That gap is the most useful single data point in this document. App store
ratings are collected in-app at moments of success, usually via a prompt after
a win. Trustpilot is where people go *after* a billing dispute. The 2.4-point
spread is not noise — it is the difference between "how does the product feel
mid-lesson" and "how did this company treat me."

Do not benchmark against the 4.9. Benchmark against the 2.5, because that is
where the unmet demand is.

### 1.3 What the 1- and 2-star reviews actually say

Per R0.5.1, complaints are the brief. Five clusters, ordered by how often they
recur:

**C1 — Billing dark patterns. By far the loudest.**
Free trials auto-converting to annual subscriptions "without clear consent";
being charged a full year instead of getting the trial; difficulty cancelling
and getting refunds **[C, corroborated across ELSA, Praktika, Loora]**.
Subscriptions "auto-charged before the second lesson." Payment taken but
subscription not activated — one Loora user reported paying twice with the same
failure **[C]**.

**C2 — Speech recognition failures, worst on Android.**
Voice-recognition glitches "especially on Android." Accuracy collapses in noisy
environments. Over-strict scoring — native speakers scoring below 90%. And the
opposite failure: the app rating deliberate, inaudible mispronunciation as
"excellent." Regional pronunciations (e.g. US Midwest) marked wrong **[C]**.

**C3 — The AI is repetitive and shallow.**
Conversations "loop with the same phrases." "Repetitive and shallow."
Praktika users report the AI speaking too fast or above the stated proficiency
level, mispronouncing words, or drifting into random accents **[C]**.

**C4 — Memory loss.** (companion category, §1.4)

**C5 — Value locked behind the paywall.**
"Good lessons paywalled," "slower real-world progress than marketed."
Confusing onboarding that demands account creation before showing any result
**[C]**.

### 1.4 The companion category, and why it matters here

Kalaam's secondary user (§3: someone who wants a good AI to talk to hands-free)
sits in this category, so its failure modes are worth knowing.

**Memory is the #1 complaint, and it is not close.** Replika users report their
companion forgetting recent conversations within days; memory reliability is
described as its single biggest user complaint. Character.AI is worse —
effectively no long-term memory, losing context within long conversations
**[C, consistent across many sources]**.

Also relevant as a warning: Luka (Replika) took a **€5M GDPR fine in Italy in
April 2025**, and in January 2025 a 67-page FTC complaint alleged the product
was deliberately designed to foster emotional dependence **[B/A]**. The PRD's
ban on guilt-based streak copy and dark patterns (§16, R4.3.5) is not just
taste — this category is under active regulatory scrutiny, and the apps being
punished are the ones that optimised engagement hardest.

### 1.5 What this means for Kalaam

The PRD's positioning survives contact with the market, and three floor
requirements turn out to be direct hits on the top complaints:

| Complaint | PRD requirement that answers it |
|---|---|
| C1 billing dark patterns | §8.3/8.4/§16 — paywall at exactly two moments, cancel via Play, no fake urgency |
| C2 recognition fails in noise | R4.2.2 — noisy-environment detection with a **non-blocking suggestion**, never a forced switch |
| C3 repetitive AI | R5.2.3 memory injection; §5.3 partners with difficulty |
| C4 memory loss | **R5.2.2 — memory that is visible and editable.** No major competitor does this |
| C5 value behind paywall | R4.3.4 — the free report must be genuinely useful on its own |

R5.2.2 is the strongest differentiator in the document and the PRD already
half-recognises it ("Most competitors hide this"). The research is stronger
than that: competitors don't merely hide memory, they are actively *bad* at it,
and users complain loudly and constantly. Visible, editable, durable memory is
not a trust feature bolted onto a language app — it is the top unmet need in the
adjacent category.

**Yoodli is the real competitor**, not Speak or ELSA. It does speech coaching
with analytics — the same job as the Session Report. Its weakness is a free
tier of **5 lifetime sessions**, which reviewers describe as a demo rather than
a usable tool, and which cannot possibly support the "come back tomorrow to
beat it" loop in PRD §3. It is also desktop/meeting-oriented (it runs during
Zoom/Meet/Teams calls). A phone-native daily practice loop with a genuinely
useful free report is an open flank.

---

## 2. Pricing benchmarks — South Asia vs US

**US/global comparables:** $6–$25/mo. Cluster: Yoodli Pro $8/mo annual, ELSA
~$11.99/mo, Speak ~$20/mo, Yoodli Advanced $20/mo, Replika $19.99/mo **[C]**.

**India:** the typical localized subscription is **₹199/month (~$2.39)**, and
Google's own recommendation engine cuts hard for the region — a $2.99 app
converts mathematically to ₹262, but Google *recommends* ₹199, a 24% cut,
because it matches local price points **[C]**. Play rounds to local anchors
(₹99 / ₹199 / ₹299). Play's minimum price floor in India is about **US$0.21**
**[A/C]**.

**Pakistan:** no reliable figure found. Not published in the sources I could
reach, and I am not going to extrapolate one. Treat Play Console's own
recommendation as authoritative when the account exists.

**Read for R8.1:** the PRD's instruction to enable regional pricing is
correct and the effect size is larger than "some discount" — it is roughly an
order of magnitude between US and South Asian price points ($20/mo vs ~$2.40/mo).
A flat USD price would not merely reduce conversion in the primary market, it
would eliminate it. The annual-at-8-months structure still works; it just
anchors near ₹1,599/yr rather than $99/yr.

One caution the PRD does not mention: Google Play's service fee. Plan the
margin on 15% for subscriptions, not the 10% headline **[C]**.

---

## 3. App store discovery

**I could not obtain real keyword volume or difficulty figures, and I am not
going to fabricate them.** Genuine per-store search volume comes from AppTweak,
Sensor Tower, or Mobile Action, all paid **[C]**. This is a zero-cost project,
so this section is qualitative until the owner has a Play Console account,
which provides real search-term data for free once the app is listed.

What the sources do support:

- **Target long-tail.** 2026 ASO consensus is that head terms ("learn english")
  are unwinnable for a new app and that longer, intent-specific phrases convert
  better at lower difficulty **[C]**. The commonly cited sweet spot is volume
  above 30 with difficulty below 50 on the 5–100 scale **[C]**.
- **Realistic targets for this app**, based on positioning rather than measured
  volume: "speaking practice", "interview practice", "presentation practice",
  "speak english alone", "practice speaking english by yourself", "fluency
  practice", "public speaking practice". The interview/presentation cluster is
  less contested than the language-learning cluster, which is defended by
  Duolingo, ELSA, and Speak with large budgets.
- **What top results do badly** — sourced from §1.3 rather than from ASO tools,
  which makes it more reliable, not less: the incumbents' listings promise
  conversation practice and their reviews say the conversation loops. The
  honest wedge in a store listing is the report and the memory, not the chat.

**Action:** revisit with real numbers after the Play Console account exists
(§17.2 requires one before Milestone 6 regardless). Do not spend money on an
ASO tool for v1.

---

## 4. Model options with usable free tiers — READ THIS ONE

### 4.1 The finding

**The PRD's zero-cost model does not survive the Gemini free tier as it exists
in 2026.** This is a floor-level problem, not a ceiling-level one, and it needs
an owner decision before Milestone 3.

Google **no longer publishes free-tier numbers in its public docs**. The
official rate-limits page now says only that limits "depend on a variety of
factors" and directs you to the AI Studio dashboard **[A —
ai.google.dev/gemini-api/docs/rate-limits]**. That alone is a planning risk: a
business model resting on an undocumented, unguaranteed quota.

Third-party trackers disagree sharply:

| Source | gemini-2.5-flash free tier |
|---|---|
| aifreeapi.com, pub. 2026-01-27 **[C]** | **10 RPM / 250 RPD**, and notes some configurations fell to 20–50 RPD |
| tokenmix.ai **[C]** | **1,500 RPD** on "Gemini Flash" |

Both agree on the direction: **on 2025-12-07 Google cut free-tier quotas by
50–80% without advance notice** **[C, multiple]**. Flash was hit hardest.

**Crucially, limits are per *project*, not per key — this is confirmed in
Google's own documentation [A].** The PRD's gateway design (R9.3) means every
user in the world shares one project's quota.

### 4.2 Why this breaks the product, with arithmetic

A spoken session is not one model call. It is **one call per conversational
turn**, plus one for the report (R4.3.2), plus memory extraction (R5.2.1).

A 10-minute session with a turn roughly every 20 seconds is ~30 turns ≈ **31+
model calls**.

| Assumed RPD | Total sessions/day, **all users combined** |
|---|---|
| 250 (pessimistic) | **~8** |
| 1,000 (Flash-Lite) | **~32** |
| 1,500 (optimistic) | **~48** |

R12.2 asks for the projected free-tier breach point at 1,000 DAU. **The real
breach point is roughly 8 to 48 daily active users**, depending on whose number
is right — between one and two orders of magnitude below where the PRD expects
trouble. Also note 10 RPM would cap *concurrency* at about ten simultaneous
speakers regardless of the daily total.

The PRD's §12 ledger line — "Model calls | Gemini API free tier | Free tier
limits | No card" — is therefore accurate on the "no card" column and
dangerously optimistic on capacity.

### 4.3 What is actually available, free, no card

| Provider | Free limits **[C]** | Notes |
|---|---|---|
| **Google Gemini** | disputed; 250–1,500 RPD | 1M context, multimodal, image understanding (needed for §5.4) |
| **Groq** | 30 RPM / 1,000 RPD / 12K TPM | **700+ tokens/sec** — by far the best fit for the R4.2.4 latency budget |
| **Cerebras** | ~1M tokens/day | up to 2,000 tokens/sec; token-based rather than request-based |
| **OpenRouter** | 20 RPM / 50 RPD free models | 50/day is too small to matter until $10 credit is added |
| **Mistral, GitHub Models** | free tiers exist | not evaluated in depth |

Multi-provider routing is standard practice precisely because each provider's
limits are independent, so routing across several multiplies free capacity
**[C]**.

### 4.4 Recommendation

The PRD's architecture is already right and should not change: R9.3.3 requires
model routing to be a server-side config value and the routing layer to be
provider-agnostic. **What must change is the assumption that one provider's
free tier is sufficient.** Concretely, for Milestone 3:

1. Build the router to fan out across **Gemini + Groq + Cerebras** from day
   one, not as a later optimisation. This is not scope creep; R9.3.3 already
   demands provider-agnosticism, and this is what it is for.
2. **Route by job.** Live conversational turns go to Groq first — it is the
   fastest free option available and R4.2.4's sub-1.5s budget is the hardest
   number in the PRD. Reports and memory extraction are not latency-sensitive
   and can go to Gemini or Cerebras. Vision (§5.4) must go to Gemini.
3. Treat R10.4's global circuit breaker as **essential infrastructure, not a
   safety net.** At these limits it will trigger in normal operation, so its
   "at capacity, try later" state needs to be a designed, non-embarrassing
   screen.
4. Make the local-only report (R4.3.1) the primary experience it already
   deserves to be. It needs no model call, so it is the only part of the
   product that scales to any number of users at zero cost. This is a
   strength the PRD already built in — it just matters far more than the PRD
   realised.

**Owner action:** open <https://aistudio.google.com/rate-limit> on a project
you control and record the real figure. It is the only authoritative number,
and no blog can substitute for it.

---

## 5. Where the market contradicts the PRD

Per R0.5.1 point 5 — stated plainly.

**5.1 The zero-cost model rests on a quota that has already been cut 50–80% and
is no longer published.** See §4. This is the one finding that should change
the plan. Mitigation is multi-provider routing (§4.4), which the PRD's own
architecture anticipates. Nothing here breaks the *no-credit-card* rule — every
provider in §4.3 has a card-free free tier — so §0.5.2's closed ceiling holds.
What breaks is the capacity assumption, not the principle.

**5.2 "Speech recognition runs on-device, so a spoken minute costs zero" is
true, and it is a bigger advantage than the PRD claims.** Given §4, on-device
recognition is not merely a margin advantage — it is the only reason the
product is viable at all. Every competitor complaint in C2 is about recognition
quality, and on-device recognition is also what makes R4.2.7 ("audio never
leaves the device") true. Three separate PRD goals converge on one decision.
Protect it.

**5.3 The PRD underrates memory as a differentiator.** §5.2.2 calls visible,
editable memory "a trust feature and a differentiator." §1.4 says it is the
single loudest complaint in the adjacent category. This deserves to be a
headline feature in store listing and onboarding, not a settings screen.

**5.4 The PRD may underrate the free-tier generosity required to compete.**
ELSA's free tier offers *unlimited* pronunciation drills and is described as
genuinely the best free pronunciation tool available **[C]**. Against that,
10 minutes/day of speaking (§8) is defensible but not obviously generous. The
counter-argument holds — ELSA's drills are a cheap local computation, whereas
spoken sessions cost model calls — but the owner should know the free-tier bar
in this category is set high by a well-funded competitor.

**5.5 Regional pricing matters more than "recommended: on" implies.** §2: the
gap is roughly 8–10×, not a discount. R8.1 should be treated as MUST.

**5.6 Nothing found contradicts** the design direction, the on-device
speech decision, the Supabase choice, or the monetization ethics. The Replika
FTC complaint and GDPR fine (§1.4) actively support §16's ban on dark patterns
and guilt-based streaks.

---

## Sources

Accessed 2026-07-26.

- [Gemini API rate limits — official docs](https://ai.google.dev/gemini-api/docs/rate-limits) **[A]**
- [Google AI Studio rate limit dashboard](https://aistudio.google.com/rate-limit) **[A]** (owner must check)
- [Set up your app's prices — Play Console Help](https://support.google.com/googleplay/android-developer/answer/6334373) **[A]**
- [Speak: Language Learning — Google Play](https://play.google.com/store/apps/details?id=com.selabs.speak) **[A]**
- [ELSA Speak — Google Play](https://play.google.com/store/apps/details?id=us.nobarriers.elsa) **[A]**
- [ELSA on Trustpilot — 2.5/5](https://www.trustpilot.com/review/elsaspeak.com) **[B]**
- [Praktika AI on Trustpilot](https://www.trustpilot.com/review/praktika.ai) **[B]**
- [Yoodli reviews — G2](https://www.g2.com/products/yoodli-inc-yoodli/reviews) **[B]**
- [ELSA reviews — Capterra](https://www.capterra.com/p/240698/ELSA-Speak/reviews/) **[B]**
- [ELSA reviews — Product Hunt](https://www.producthunt.com/products/elsa/reviews) **[B]**
- [Gemini API free tier rate limits, pub. 2026-01-27](https://www.aifreeapi.com/en/posts/gemini-api-free-tier-rate-limits) **[C]**
- [Gemini API free tier limits — TokenMix](https://tokenmix.ai/blog/gemini-api-free-tier-limits) **[C]**
- [Free LLM APIs 2026 compared — OpenRouter](https://openrouter.ai/blog/tutorials/free-llm-apis-compared/) **[C]**
- [Best free LLM API tiers 2026](https://wetheflywheel.com/en/ai-model-access/free-llm-api-tiers-2026/) **[C]**
- [Google Play pricing strategy 2026](https://regionalpricecalculator.com/blog/google-play-pricing-strategy.html) **[C]**
- [Google Play IAP pricing by country](https://pricepush.app/blog/google-play-iap-pricing-by-country) **[C]**
- [Google Play subscription fees 2026](https://pricepush.app/blog/google-play-subscription-fees-2026-real-math) **[C]**
- [Yoodli review — FinalRound AI](https://www.finalroundai.com/blog/yoodli-review-pros-cons) **[C]**
- [Yoodli pricing — Prospeo](https://prospeo.io/s/yoodli-pricing-reviews-pros-and-cons) **[C]**
- [Is Speak legit? 5 AI English apps checked — Unstar](https://unstar.app/blog/is-speak-elsa-talkpal-loora-learna-ai-english-apps-legit-2026) **[C]**
- [Best AI language speaking practice apps 2026 — Talkio](https://www.talkio.ai/blog/best-ai-language-speaking-practice-apps-in-2026) **[C]**
- [Replika review 2026 — Scribe](https://scribehow.com/page/Replika_Review_2026_The_AI_Companion_That_Got_Fined_euro5M__Is_It_Still_Worth_Using__siVxaR7TShSgBhaRaZ6osg) **[C]**
- [Best AI companions with long-term memory 2026](https://blog.getsoullink.com/best-ai-companions-with-long-term-memory-in-2026/) **[C]**
- [App Store keyword research for ASO 2026 — AppTweak](https://www.apptweak.com/en/aso-blog/app-store-keyword-research-aso) **[C]**
