# DECISIONS.md

Architectural and product decisions that deviate from, amend, or interpret the
PRD. Required by PRD §0.3 (SHOULD-level deviations), R12.1, R12.2, and R9.3.6.

Newest first. Every entry records what changed, why, what it costs, and what
would reverse it.

---

## D10 — `riverpod_annotation` and `riverpod_generator` are removed, though F5 names one of them

**Date:** 2026-07-29 · **Status:** accepted · **Deviates from:** PRD F5's
package list · **Implements:** F5's actual requirement, and §14's "pubspec.yaml
contains only packages this PRD requires"

**What.** Both packages are gone from `pubspec.yaml`. `flutter_riverpod` stays
and nothing about the state management changes.

**Why this is not a reduction in scope.** F5 says: "Migrate Provider to Riverpod
(`flutter_riverpod` + `riverpod_annotation`). This is what removes F3 cleanly
and makes quota/entitlement state testable." The requirement is the migration
and its two named outcomes. Both are done and both are guarded executably —
`architecture_test.dart` fails if `package:provider`, `Provider.of`,
`context.read`, or `context.watch` reappears anywhere in `lib/`, and no service
holds a `BuildContext`. The parenthesis names a *means*, and this project chose
a different one.

**The evidence that it was never used.** Across four milestones:
`grep -rn "@riverpod\|riverpod_annotation" lib/` returns nothing, there is no
`.g.dart` anywhere in `lib/`, and there is no `build.yaml`. Every provider in
the app is declared by hand — `NotifierProvider(ChatController.new)`,
`Provider<GatewayClient>((ref) => …)` — which is a deliberate and visible style,
not an oversight. The annotation package was a dependency with zero imports and
the generator was a build step with zero outputs.

**Why it had to be decided now rather than left alone.** `riverpod_generator`
pins `build ^2.0.0`. `drift_dev` requires `build >=3.0.0`. Drift is §9.4's
local persistence, which is what makes R4.2.6's "a session that is force-killed
MUST still produce a report from whatever transcript was persisted" true. So
the choice was between an unused generator and a required capability, and an
unused generator does not get to veto a dependency the product needs.

**Cost.** If a later milestone wants generated providers, it re-adds both and
pays whatever the `build` conflict costs at that time. That is a real cost and
it is the reason this is written down rather than done quietly. It is also
bounded: `drift_dev` and `riverpod_generator` will not conflict forever, and
the migration would be mechanical.

**What was NOT removed.** `riverpod_lint` and `custom_lint` stay. Their useful
rules are about `ref` misuse and provider lifecycle, which apply to hand-written
providers exactly as much as to generated ones.

**Reverses if:** a milestone has enough providers that hand-declaring them
becomes the error-prone option, and `riverpod_generator` has by then moved to
`build ^3`.

---

## D9 — The app is SpeakWise, and the package id is `com.muscodes.speakwise`

**Date:** 2026-07-28 · **Status:** settled by the owner · **Closes:** PRD §17.1
and §17.2 · **Blocks nothing further**

**What.** The working name Kalaam is retired. The product is **SpeakWise**, the
Android `applicationId` and iOS bundle identifier are `com.muscodes.speakwise`,
the Dart package is `speakwise`, and the OAuth deep link is
`com.muscodes.speakwise://login-callback/`.

**Why now rather than later.** §17.2 says the package id "can never change
after publishing", so this had to be settled before Milestone 6 puts anything
in the Play Console. It was also the cheapest it will ever be: the rename
touched 52 files of Dart imports mechanically, and every one of those would
have been a file that also contained session, report, or paywall code if it had
waited two milestones.

The app had accumulated **three** names, which is what made it urgent rather
than merely tidy. The splash said `ChadGPT`, the welcome screen said "Welcome
to ChadGPT", the Android launcher label said `ChadGPT`, the package said
`com.muscodes.kalaam`, the iOS bundle still said `com.muneeb.aichatbot`, and
the ARB said `Kalaam`. Two of those were found in the Milestone 3 device pass;
the iOS one was found by this rename and had survived since before Milestone 0.

**Cost, and who pays it.** The Android `applicationId` is the OAuth client's
identity, so the rename invalidates the Google Cloud OAuth client and the
Supabase Auth configuration on both projects. **Google sign-in is broken until
the owner recreates the Android client and re-registers the redirect URL**,
which is manual work in two consoles and cannot be done from here. Email and
password sign-in is unaffected. The checklist is in `README.md`.

Installed debug builds do not upgrade — a new `applicationId` is a different
app to Android — so the old build must be uninstalled by hand.

**What is deliberately NOT renamed.**

- **The Supabase projects.** They stay `kalaam` and `kalaam-dev`. A project
  name is a dashboard label; the refs are what every URL, key, migration, and
  test actually resolves against, and refs cannot change. Renaming would cost
  confusion and buy nothing.
- **The GitHub repository**, still `muneebexotic/ai_chatbot_app`. Renaming it
  breaks every URL in `SECURITY-REMEDIATION.md`, which is a runbook that has to
  work under pressure. GitHub redirects the old name, so the cost of leaving it
  is a mismatch in the address bar and the cost of changing it is a document
  that lies about where to clone from.
- **The header comment on `20260727155452_initial_schema.sql`**, which still
  reads "Kalaam initial schema". It is a historical file describing what was
  written that day, under the name the project had.

**One thing that WAS rewritten in a historical document, stated plainly.**
`CRITIQUE.md` referred to `KalaamTheme` and `kalaam_theme.dart` in the
Milestone 1 entries. Those identifiers are now `SpeakWiseTheme` and
`speakwise_theme.dart`, and the references were updated so a reader following
them lands on real code. **No claim, finding, or date was altered** — only the
names of the things being pointed at. Recorded here rather than left for
someone to notice in a diff.

**Reverses if:** never. Once `com.muscodes.speakwise` reaches Play it is
permanent, which is the entire reason §17.2 flagged it.

---

## D8 — The read-own policies on `entitlements` and `usage_daily` are proven through the gateway, not with a service key in the test suite

**Date:** 2026-07-28 · **Status:** accepted · **Closes:** CRITIQUE W2.3 ·
**Implements:** PRD R9.5.1, R9.3.4, §14

**The gap.** Fourteen RLS tests prove one user cannot reach another's rows,
and an anon-write probe covers all ten tables. Two tables are only half
covered: `entitlements` and `usage_daily` are proven to *refuse* client
writes, but their read-own policies are unproven, because creating a row to
read requires the service-role key. W2.3 states why that matters — the untested
half is the half that decides whether a paying user can see what they paid for,
and a read-own policy that silently returns nothing looks exactly like "no
subscription" in the UI.

**The two options.** Either give the test suite a dev service-role key, or wait
for something that legitimately holds one.

**Chosen: wait, and then use the gateway.** The gateway (§9.3) writes
`usage_daily` under service role, atomically with the response it accounts for
(R9.3.4), and reads or creates the caller's `entitlements` row on every call
(R9.3.1). So the sequence a test needs already exists in production code:

1. Sign in to `kalaam-dev` as a throwaway user.
2. Send one message through the gateway with that user's JWT.
3. Read `usage_daily` and `entitlements` back **as that user**, through the
   anon key and therefore through RLS.

A row appears, the user can read it, and neither the test nor the developer
running it ever holds a key that bypasses RLS.

**Why this is better than a dev service key, not merely cheaper.**

- **A service key in a test suite is a service key on every developer's disk
  and in CI.** It bypasses RLS by definition, which makes it the single
  credential in this project whose leak would be unrecoverable without rotating
  the database. §1 exists because this repo leaked four credentials for eleven
  months. Adding a fifth to prove a `select` works is a poor trade.
- **It tests the wrong thing.** A row seeded by the test suite proves the
  policy accepts a row the test knows how to shape. A row written by the
  gateway proves the policy accepts *the row the product actually writes* —
  which is the claim W2.3 is worried about.
- **It closes a second gap for free.** §14 requires proving that "a patched
  client cannot gain Pro". The same test, run with a forged `tier: pro` in the
  request body, shows the gateway ignores it.

**Cost.** The coverage gap stays open for the length of Milestone 3 rather than
being closed immediately, and the test is an integration test that self-skips
without `--dart-define=SUPABASE_URL`, so it does not run on a machine with no
network. That is the same shape as the existing 24 integration tests and is
recorded in `CLAUDE.md` under commands.

**Not deferred indefinitely.** This is a Milestone 3 deliverable, not a
milestone-4 hope. If Milestone 3 closes without it, W2.3 is re-entered in
`CRITIQUE.md` as unfixed twice, which is a different and worse finding.

**Reverses if:** the gateway turns out not to write `usage_daily` on a typed
message — for instance if §8's message counter moves somewhere else. Then the
choice is between seeding through some other service-role function and
accepting the key, and it should be re-argued rather than assumed.

---

## D7 — `abuse_events` is service-role write and no client read

**Date:** 2026-07-27 · **Status:** accepted · **Interprets:** PRD R9.5.1, §10

**What.** `abuse_events` has RLS enabled and **no policy at all** for the
`authenticated` role — no select, no insert, no update, no delete. Only the
service role touches it.

**Why this is an interpretation, not the letter.** R9.5.1 says a user may read
and write their own rows, and names only `entitlements` and `usage_daily` as
service-role write. Read literally, a user would be able to insert, edit, and
delete rows in `abuse_events` — the table that exists to record that user's
abuse. That would let the party being detected rewrite the detection, which
defeats §10 entirely and cannot be what the requirement intends.

Read access is withheld as well, which goes one step further than the write
restriction. `detail` describes what the detector matched on; exposing it to the
account being measured is free reconnaissance for anyone probing the limits.

**Cost.** No in-app path can ever show a user their own abuse history. If that
becomes a transparency requirement — a GDPR access request would be the obvious
trigger — it is served by an Edge Function under service role that returns a
redacted view, not by relaxing this policy.

**The absence of a policy is the mechanism.** RLS denies by default: a table
with RLS enabled and no matching policy rejects the statement. Someone reading
this migration may see a table with no policies and conclude it was forgotten.
It was not, and the migration says so at the table.

**Verified:** an anon insert into every one of the ten tables returns `42501`
(row-level security violation) rather than a constraint error, confirming RLS is
enabled and denying rather than merely declared.

**Reverses if:** a regulator or Play policy requires user-visible abuse records,
which is handled by the redacted-view function above rather than by a policy
change.

---

## D6 — A debug-only launcher stands in for sign-in until Milestone 2

**Date:** 2026-07-27 · **Status:** CLOSED 2026-07-28 — deleted as specified ·
**Follows:** D0

**What.** `lib/debug/debug_preview.dart` opens Chat with seeded fake messages,
opens Settings, toggles light/dark, and enters the normal Splash flow. It is
the initial screen when `kDebugMode` is true and is absent from release builds
entirely, since `kDebugMode` is a compile-time constant.

**Why.** D0 records that Google suspended the Firebase project, so sign-in
cannot succeed on any device. Chat and Settings are the two screens carrying
the most theme-dependent code — Settings alone reads `Theme.of(context)`
21 times — and both sit behind that login. Without a bypass, Milestone 1's
theme wiring could only ever be verified against the contrast table, which is
precisely the weakness W1.1 exists to record. Worse, the app's only light/dark
switch is inside Settings, so even the light-mode pass was unreachable.

**Cost.** A screen and a branch in `main.dart` that must be deleted, and one
dependency on an existing encapsulation leak: `ChatProvider.messages` returns
the provider's own mutable list, which is how seeding works without touching
shipped code. The leak is pre-existing and is not widened here.

**Not what it is.** Not a fix for auth, not a fake user, not a mock backend.
Nothing in `lib/` outside the debug file and the guarded branch changed. The
conversation drawer still reads Firestore and still comes up empty.

**Deletion.** Both sites are marked `TODO(m2-delete)`. Milestone 2 rewrites
these screens against Supabase; the file and the branch go with it. If
Milestone 2 ships with `lib/debug/` still present, that is a defect.

**Reverses if:** the Firebase project is restored, or Milestone 2 lands early
enough that real auth is available. Neither is expected — D0 abandons the
project rather than appealing it.

---

## D5 — Riverpod migration keeps `ChangeNotifier` for now

**Date:** 2026-07-26 · **Status:** accepted, time-boxed · **Implements:** PRD F5

**What.** `package:provider` is removed entirely — no `MultiProvider`, no
`Provider.of`, no `context.read`. The graph is Riverpod, rooted in a
`ProviderScope`, declared in `lib/app/providers.dart`. But the six state
classes behind it are still `ChangeNotifier`, exposed through Riverpod's
`ChangeNotifierProvider` rather than rewritten as `Notifier`.

**Why.** F5's stated purpose is "what removes F3 cleanly and makes
quota/entitlement state testable". That comes from the dependency
*injection*, and that part is done and verified: no service holds a
`BuildContext`, no provider stores one, and every class in the graph can be
constructed in a test. Rewriting `AuthProvider` (770 lines), `PaymentService`
(900+), and four others into `Notifier` at the same time would have been a
simultaneous rewrite of several thousand lines of code that Milestones 2–5
are going to replace anyway, with no way to tell a migration bug from a
rewrite bug.

`ChangeNotifierProvider` is Riverpod's own documented migration path off
`package:provider`, so this is the intended intermediate state, not a
workaround.

**Cost.** The state classes do not yet get Riverpod's compile-time safety or
its `AsyncValue` handling. `ref.watch` on a `ChangeNotifier` rebuilds on any
`notifyListeners()` rather than on the specific field read.

**Reverses if:** never — each becomes a `Notifier` as its feature is rebuilt
(auth in Milestone 2, chat in Milestone 3, entitlements in Milestone 6), at
which point it is a rewrite of code already being rewritten.

**Guarded by:** `test/architecture_test.dart` fails if `package:provider`,
`Provider.of`, `context.read`, or `context.watch` reappears anywhere in `lib/`.

---

## D4 — Three markdown renderers survive Milestone 1

**Date:** 2026-07-26 · **Status:** accepted, time-boxed · **Defers:** PRD §2.2
("keep exactly one renderer") to Milestone 3

**What.** `flutter_markdown`, `flutter_highlight`, and `markdown` stay in
`pubspec.yaml` alongside `gpt_markdown` for now. `markdown_widget` is removed —
it had zero usages.

**Why.** `app_message_bubble.dart` is 846 lines built on `flutter_markdown`
plus a custom `flutter_highlight` code-block builder. PRD §7.4 replaces that
widget wholesale in Milestone 3: AI turns stop being bubbles and become
full-width Newsreader paragraphs with a `signal` rule on the left. Porting it
to `gpt_markdown` now would be work discarded one milestone later, and it would
be done against the old design rather than the new one.

§14's "exactly one renderer" is an acceptance criterion for the finished
rebuild, not for this milestone. The dependency lines carry `# REMOVE in
Milestone 3` markers.

**Cost:** three unnecessary packages in the dependency tree, and a slightly
larger debug APK, for the duration of Milestone 2.

**Reverses if:** Milestone 3 slips far enough that these linger past the chat
rebuild, at which point the port should happen on its own.

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
