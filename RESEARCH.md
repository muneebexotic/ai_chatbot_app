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

**Read §4 first. It contains two independent findings — a capacity problem
(§4.A) and a terms problem (§4.B) — and each on its own contradicts a
load-bearing assumption in the PRD. §4.B is the more serious of the two and was
missed entirely on the first pass of this research.**

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

## 4. The free-tier problem — TWO independent findings

**There are two, not one. They are unrelated in cause, they compound in
effect, and either alone is enough to force a decision before Milestone 3.**

- **§4.A — Capacity.** The free quota is far too small for the product.
- **§4.B — Terms.** Google's unpaid tier trains on user content, allows human
  review of it, and cannot lawfully serve Europe at all.

§4.B is the one that matters more, because capacity is an engineering problem
and terms are a promise problem. Kalaam's privacy claim (R4.2.7: "audio never
leaves the device... state this plainly in the UI, because it is both true and
a genuine selling point") is a load-bearing part of the product's honesty. On
Gemini's unpaid tier, the accompanying claim about transcripts would not be.

---

### 4.A Capacity

Google **no longer publishes free-tier numbers in its public docs**. The
official rate-limits page says only that limits "depend on a variety of
factors" and directs you to the AI Studio dashboard **[A —
ai.google.dev/gemini-api/docs/rate-limits]**. A business model resting on an
undocumented, unguaranteed quota is itself the risk.

Third-party trackers disagree sharply:

| Source | gemini-2.5-flash free tier |
|---|---|
| aifreeapi.com, pub. 2026-01-27 **[C]** | **10 RPM / 250 RPD**, notes some configurations fell to 20–50 RPD |
| tokenmix.ai **[C]** | **1,500 RPD** on "Gemini Flash" |

Both agree on direction: **on 2025-12-07 Google cut free-tier quotas by 50–80%
without advance notice** **[C, multiple]**. Flash was hit hardest.

**Limits are per *project*, not per key — confirmed in Google's own docs [A].**
The gateway design (R9.3) means every user in the world shares one quota.

#### The arithmetic

A spoken session is **one model call per conversational turn**, plus the report
(R4.3.2), plus memory extraction (R5.2.1). A 10-minute session at a turn every
~20 seconds is ~30 turns ≈ **31+ calls**.

| Assumed RPD | Sessions/day, **all users combined** |
|---|---|
| 250 (pessimistic) | **~8** |
| 1,000 (Flash-Lite) | **~32** |
| 1,500 (optimistic) | **~48** |

R12.2 asks for the breach point at 1,000 DAU. **The real one is roughly 8–48
daily active users** — one to two orders of magnitude below where the PRD
expects trouble. Separately, 10 RPM caps *concurrency* at about ten
simultaneous speakers regardless of the daily total.

---

### 4.B Terms — training, human review, and a hard block on Europe

Primary source: **Gemini API Additional Terms of Service [A]**.

**Four distinct provisions, all applying to the unpaid tier:**

**1. Google trains on submitted content.**
> "Google uses the content you submit to the Services and any generated
> responses to provide, improve, and develop Google products and services and
> machine learning technologies."

**2. Humans may read it.**
> "To help with quality and improve products, human reviewers may read,
> annotate, and process your API input and output."

**3. Do not send personal information.**
> "Do not submit sensitive, confidential, or personal information to the Unpaid
> Services."

**4. Europe requires the paid tier — an availability restriction, not just a
data one.**
> "You may use only Paid Services when making API Clients available to users in
> the European Economic Area, Switzerland, or the United Kingdom."

Note there are **two separate EEA provisions** and they are easy to confuse.
The one above restricts *who you may serve* on the free tier. A different
clause says that for users in those regions, paid-tier data protections apply
to all services including free ones. The second does not cancel the first: the
data carve-out protects the user, the availability clause still binds the
developer. Reading only the second gives a dangerously reassuring answer —
which is exactly the mistake made on the first pass of this research. Scope
extends to the UK, Switzerland, Norway, Iceland, and Liechtenstein **[C]**.

#### Why this is disqualifying for Kalaam specifically

This is not generic API boilerplate that every app lives with. It collides with
four things the PRD treats as non-negotiable:

| PRD requirement | Conflict |
|---|---|
| **R4.2.7** — audio never leaves the device, "state this plainly in the UI... a genuine selling point" | Transcripts *do* leave, and on the unpaid tier they train a third-party model and may be read by humans. The privacy story becomes technically true but misleading |
| **R5.2.1 / R5.2.4** — memory extraction sends durable personal facts; sensitive categories must never be stored | Sending exactly the content the terms say not to send. The R5.2.4 filter protects *our* database, not Google's training set |
| **§16** — "No invented facts", and the honesty running through the §7.6 copy rules | A privacy claim that omitted this would be the kind of thing §16 exists to prevent |
| **§3, R11.7** — South Asia primary, Urdu as first follow-up | Europe is not the primary market, so the block is survivable — but it forecloses a market rather than deferring it, and that should be a knowing choice |

The session transcript is the single most personal artefact this app produces.
It is someone practising for a job interview, rehearsing a difficult
conversation, or speaking a second language badly on purpose. That is precisely
the content the terms tell you not to submit.

---

### 4.C What is actually available, free, no card

The terms columns are the important ones. They invert the obvious ranking.

| Provider | Free limits **[C]** | Trains on your content? | Serves EEA/UK? |
|---|---|---|---|
| **Gemini (unpaid)** | disputed; 250–1,500 RPD | **Yes**, plus human review **[A]** | **No — paid only [A]** |
| **Groq** | 30 RPM / 1,000 RPD / 12K TPM | **No** — contractually prohibited **[A]** | no restriction found |
| **Cerebras** | ~1M tokens/day | **No** — no retention, no training **[C]** | independent controller |
| **OpenRouter** | 20 RPM / 50 RPD free models | varies by model | varies |

**Groq [A], Services Agreement:**
> "Groq is not permitted to use Inputs or Outputs for training or fine-tuning
> any AI Model Services or other models, unless explicitly granted permission"

The agreement makes **no free/paid distinction** on this point — it applies at
every tier. Zero-data-retention is additionally available to eligible
customers. **Cerebras** reportedly does not retain or train on user data
**[C — not verified against the primary EULA; verify before relying on it]**.

Groq is also the fastest free option at 700+ tokens/sec **[C]**, the best
available shot at the R4.2.4 sub-1.5-second latency budget.

**So the free provider with the worst terms is the one the PRD names as the
default, and two alternatives are both faster and contractually cleaner.**

---

### 4.D Recommendation

The PRD's architecture is right and should not change: R9.3.3 already requires
server-side model routing and a provider-agnostic layer. What must change is
the assumption that Gemini's free tier is a suitable default.

1. **Live conversational turns → Groq.** Fastest free option, and the only one
   of the three with an explicit contractual ban on training that covers the
   free tier. Latency and privacy point the same way.
2. **Reports and memory extraction → Groq or Cerebras**, not Gemini unpaid.
   These carry the most personal content and are not latency-sensitive.
3. **Vision (§5.4) → Gemini is the only free option.** Either accept the terms
   for images specifically and disclose it, or defer image understanding past
   v1. Recommend deferring: §5.4 is a supporting feature, not the product.
4. **Treat R10.4's circuit breaker as core infrastructure, not a safety net.**
   At these limits it fires during normal operation, so "at capacity, try
   later" needs to be a designed screen.
5. **Whatever is chosen, the privacy copy must match it exactly.** If any
   transcript reaches a provider that trains on it, R4.2.7's UI statement must
   say so in plain words.

**Owner actions:** (a) open <https://aistudio.google.com/rate-limit> and record
the real quota; (b) read the Groq Services Agreement and the Cerebras EULA in
full before either is wired in — the Cerebras position above is **[C]** and has
not been verified at the source.

## 5. Where the market contradicts the PRD

Per R0.5.1 point 5 — stated plainly.

**5.1 The zero-cost model rests on a quota that has already been cut 50–80% and
is no longer published.** §4.A. Mitigation is multi-provider routing, which the
PRD's own architecture anticipates. It buys roughly 2–3x, not a fix — see
`PROPOSALS.md` P1.

**5.2 The named default provider's terms are incompatible with the product's
privacy claim, and bar Europe outright.** §4.B. This is the more serious of the
two findings and it is not solvable by engineering. It is solvable by provider
choice (Groq/Cerebras), by revenue (paid tiers end training and unblock the
EEA), or by disclosure. It is not solvable by staying on Gemini's free tier and
saying nothing.

**5.3 "Speech recognition runs on-device, so a spoken minute costs zero" is
true, and it is a bigger advantage than the PRD claims.** Given §4, on-device
recognition is not merely a margin advantage — it is the only reason the
product is viable at all. Every complaint in cluster C2 is about recognition
quality, and on-device recognition is also what makes R4.2.7 true. Three PRD
goals converge on one decision. Protect it.

**5.4 The PRD underrates memory as a differentiator.** §5.2.2 calls visible,
editable memory "a trust feature and a differentiator." §1.4 says it is the
single loudest complaint in the adjacent category. It deserves to be a headline
in the store listing and onboarding, not a settings screen.

**5.5 The PRD may underrate the free-tier generosity required to compete.**
ELSA's free tier offers *unlimited* pronunciation drills and is described as
genuinely the best free tool in the category **[C]**. Against that, 10
minutes/day is defensible but not obviously generous. This is the argument that
became `PROPOSALS.md` P2.

**5.6 Regional pricing matters more than "recommended: on" implies.** §2: the
gap is roughly 8–10x, not a discount. R8.1 should be treated as MUST. Plan
margin on Play's 15% subscription fee, not the 10% headline **[C]**.

**5.7 Nothing found contradicts** the design direction, the on-device speech
decision, the Supabase choice, or the monetization ethics. The Replika FTC
complaint and GDPR fine (§1.4) actively support §16's ban on dark patterns and
guilt-based streaks.

---

## Sources

Accessed 2026-07-26.

- [Gemini API rate limits — official docs](https://ai.google.dev/gemini-api/docs/rate-limits) **[A]**
- [**Gemini API Additional Terms of Service**](https://ai.google.dev/gemini-api/terms) **[A]** — training, human review, EEA/CH/UK restriction
- [**Groq Services Agreement**](https://console.groq.com/docs/legal/services-agreement) **[A]** — no training on inputs/outputs, all tiers
- [Groq privacy policy](https://groq.com/privacy-policy) **[A]**
- [Cerebras Inference terms](https://d7umqicpi7263.cloudfront.net/eula/4rCqa7snChhObjYFAYH325D2kcqkCRpGXBZYsSMc3mg) **[A]** — not yet read in full
- [Clarification on "Only Paid Services" for EEA/CH/UK — Google AI Developers Forum](https://discuss.ai.google.dev/t/clarification-on-only-paid-services-for-eea-ch-uk/107860) **[B]**
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
