# CLAUDE.md

Guidance for Claude Code working in this repository. Created in Milestone 0 per
PRD §0.7. Keep it current — if you change the stack, a command, or a token,
update this file in the same commit.

## Read first

`PRD-kalaam-rebuild.md` (one directory up, at the workspace root) is the
authority. This file summarises it; it does not replace it or override it.
Read the PRD in full before writing code.

Two rules from it that decide most arguments:

- **§0.5.2 — closed ceilings.** The security model, the zero-cost rule, the
  privacy categories, monetization ethics, the stack, the design anti-brief,
  and the milestone order are not open to improvement. Exceeding them is a
  failure, not initiative.
- **§0.5.3 — propose before you build.** Anything beyond the PRD's floor goes
  in `PROPOSALS.md` and waits for the owner. Exception: craft-level polish that
  adds no new surface area (better animation, copy, layout) — build that on
  sight.

## What this project is

**SpeakWise** — a voice-first AI you speak to, which reports back on how you
sounded. Not a chat wrapper. A Session (live spoken conversation → report) is
the product; typed chat is the quiet half.

The name was settled on 2026-07-28 (DECISIONS D9); the PRD and older commits
call it **Kalaam**, which was the working name. The Supabase projects are still
named `kalaam` / `kalaam-dev` on purpose — refs are what matter, not labels.

The loop that pays: speak → report → weak spot → return tomorrow → hit the free
minute cap → subscribe. Retention and monetization are the same loop, which is
why the report is the flagship.

## Current state — read this before believing any file

This is a **rebuild in progress on a live codebase**, not a greenfield project.
Half the app is now the new one; the other half is the pre-rebuild app waiting
for its milestone.

| | Now | Target (PRD) |
|---|---|---|
| State | Riverpod. `chat`/`partners`/`memory` are real `Notifier`s; four `ChangeNotifier` shims remain (D5) | Riverpod `Notifier` throughout |
| Auth | **Supabase** (M2) | Supabase |
| Data | **Supabase Postgres + RLS.** Firebase is gone entirely (M3) | Supabase Postgres + RLS |
| Model calls | **Server gateway only, key server-side** (M3) | Server gateway only |
| Layout | `features/{chat,partners,memory,auth}` are PRD-shaped; `screens/`, `providers/`, `services/` still hold auth, settings, subscription | `lib/app`, `core`, `design`, `features/*`, `l10n` (§13) |
| Type | Newsreader + General Sans + Geist Mono, rendering on the chat surface | same |
| Errors | `Result<T>` / sealed `AppFailure` | same |
| Copy | ARB from `lib/l10n`, with a ratchet over the 127 strings still hardcoded | no hardcoded strings in `lib/` |
| Images | Understanding only, not yet built | Understanding only, via gateway |

**`.kiro/steering/*.md` describes the OLD architecture** (Provider, Firebase,
Poppins). It is stale and contradicts the PRD. Do not follow it; the PRD wins.

Milestone status: **0, 1, 2, 3 done.** 4–8 not started. Do them in order
(PRD §15); the order is a closed ceiling.

What M3 landed: the gateway Edge Function (JWT, entitlement, quota, §10 abuse
checks, Groq streaming, atomic usage recording), typed chat rebuilt on §7.4,
partners as rows, memory extraction and the Memory screen, `flutter_localizations`
+ ARB, and Firebase deleted. **No model key ships in the APK any more** — the
built artefact contains no key and does not mention `api.groq.com`
(`qa/m3-device-pass.md`), which closes CRITIQUE W0.3.

What M3 deliberately did not: a purchase now grants **nothing**. R8.2 and §14
forbid granting on an unverified token, `entitlements` is service-role write
only, and `verify-purchase` is M6 — so the paywall is reachable and inert
(CRITIQUE W3.3). Read "monetization" as absent, not partial.

## Stack

- Flutter 3.38.6 / Dart 3.10.7 (SDK constraint `^3.8.1`)
- Riverpod for state and DI — services never touch `BuildContext`
- Supabase: Auth, Postgres with RLS, Edge Functions (Deno/TypeScript), Storage
- **Groq** for model calls, reached only through the gateway (D3). The client
  has no provider SDK and no provider hostname; swapping providers is a row in
  `gateway_config`, not a release.
- Deno 2.x to run the Edge Function tests. Not on PATH — installed at
  `~/.deno/bin/deno.exe`.
- Drift (SQLite) for local threads/messages/sessions/reports — **not added
  yet**; §9.4 offline history arrives with Milestone 4. Today the client reads
  Postgres directly and has no offline story. `shared_preferences` for settings
  only.
- `speech_to_text` and `flutter_tts` — both **on-device**. This is the whole
  business model: a spoken minute costs zero, so voice practice is free to run
  for a solo developer and expensive for a funded competitor. Never replace
  either with a cloud service.
- `gpt_markdown` — the single markdown renderer. Not `markdown`,
  `flutter_markdown`, `markdown_widget`, or `flutter_highlight`.
- Targets: **Android first, iOS kept compiling.** No web, Windows, macOS, or
  Linux; those folders are gone and `architecture_test.dart` fails if one
  returns.

## Commands

```bash
flutter pub get                     # also runs gen-l10n (pubspec `generate: true`)
flutter analyze                     # must be clean, no ignored rules (§14)
flutter test --coverage             # domain + application ≥70% (§14)

# Only two defines now. There is no model key here any more — the gateway holds
# it as a Supabase Function secret, which is the whole point of R9.3.
# Point them at kalaam-dev while developing.
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...

flutter test                        # 119 offline; integration tests self-skip
flutter test --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
                                    # +34 against kalaam-dev (RLS, auth, gateway)

~/.deno/bin/deno.exe test --allow-read --allow-net supabase/functions/tests/
                                    # 29 Edge Function tests (§14)

dart run test/tool/update_l10n_baseline.dart   # after extracting strings, never
                                               # to make a failing test pass

npx supabase link --project-ref <ref>   # dev: sbwaiindthrluqoypvqc
npx supabase db push                    # prod: kneiwapwjuuaxcenlfsu
npx supabase functions deploy gateway
npx supabase functions deploy extract-memory
npx supabase functions deploy delete-account
npx supabase secrets set GROQ_API_KEY=...   # server-only, never a --dart-define
flutter build apk --split-per-abi   # per-ABI under 30MB (R11.1)

bash scripts/check-secrets.sh       # staged content; runs from pre-commit
bash scripts/check-secrets.sh --all # whole tracked tree; use in CI
bash scripts/check-secrets.test.sh  # 40 cases, must stay green
```

First thing in a new clone:

```bash
git config core.hooksPath .githooks
```

Hooks are not transferred by `git clone`. Without this the secret scanner never
runs.

## Security rules — non-negotiable

Full policy in `SECURITY.md`; incident history and the owner's runbook in
`SECURITY-REMEDIATION.md`.

- **No secret in the client, ever.** Not in source, not in a committed `.env`,
  not obfuscated. An APK is a zip; every string in it is public. This repo
  leaked four credentials for ~12 months. Do not add a fifth.
- `--dart-define` keeps keys out of *source*, not out of the *binary*. That is
  why it was only ever a stopgap, and why CRITIQUE W0.3 refused to call
  Milestone 0 a fix. **The gateway (R9.3) is the fix and it landed in Milestone
  3**: the server holds the model key, the client holds a user JWT, and the
  built APK contains no key and no provider hostname (`qa/m3-device-pass.md`).
  The two defines that remain are the Supabase URL and publishable key, which
  R9.6 says are public by design — security there comes from RLS.
- **Entitlements are server-truth** (F2). The client displays; it never
  enforces. Purchases verified against the Play Developer API before any
  entitlement is written.
- **Client input is hostile.** The gateway accepts partner id, thread id, user
  text. Model, temperature, system prompt, and safety settings are
  server-decided and schema-validated (R9.3.2).
- **RLS on every table**, with a test per table. `entitlements` and
  `usage_daily` are service-role write only (R9.5.1).
- Never commit `.env`, `google-services.json`, `*.jks`, `*.keystore`, or
  `key.properties`. If a key reaches a push, **revoke it first** — history
  rewriting is cleanup, never containment.

### `.gitignore` is UTF-8, no BOM

Adding rules from PowerShell writes UTF-16LE, which git reads as
`.\0e\0n\0v` — a rule that looks right and matches nothing. That is exactly how
a live token stayed tracked here for eleven months. Use:

```powershell
Add-Content .gitignore 'rule' -Encoding utf8
```

## Architecture rules

Layers (PRD §9.1), strictly one-directional:

```
presentation  (screens, widgets)
   ↓
application   (Riverpod notifiers, use cases)
   ↓
domain        (models, Result / AppFailure)
   ↓
data          (repositories, remote + local data sources)
```

- Widgets never call a data source directly.
- **Services never import `flutter/material.dart`** and never take a
  `BuildContext`. Constructor-inject plain dependencies. (F3: the old
  `GeminiService(BuildContext)` read providers in its constructor — do not
  reproduce that shape.)
- Models are immutable.
- Errors are typed. Return `Result<T>`; never return `null` to signal failure
  and never swallow an exception. The UI must be able to distinguish offline,
  rate-limited, quota-exceeded, safety-blocked, and unknown, and say something
  specific for each (F4, R11.5).
- No `print()`. Use the `Log` utility, which no-ops in release.
- No hardcoded user-facing strings anywhere in `lib/` — everything through
  `l10n/` ARB files (R11.7). Enforced by `test/l10n_test.dart` as a **ratchet**:
  a file not in `test/l10n_baseline.txt` must have zero, so everything written
  from Milestone 3 on is localized from birth. The baseline may only shrink.
- **Anything user-facing must be verified by running the app.** Not a
  suggestion: every real defect in Milestones 1, 2 and 3 was found by looking
  at a screen, and none was reachable by the analyzer or the suite (CRITIQUE
  W1.1, W2.1, W3.1). Layout bugs in particular are invisible to every static
  rule in this repo — `Row(crossAxisAlignment: stretch)` inside a `ListView`
  rendered every AI reply at zero height while analyze was clean.
- **Pump widget tests inside the parent they actually have.** A `ListView`
  gives its items a tight cross-axis constraint and an unbounded main-axis one.
  Both Milestone 3 layout bugs pass in a bare `Scaffold`.
- Migrate Provider → Riverpod screen by screen, but never leave the app
  half-migrated at the end of a milestone (F5).
- All schema changes are committed migration files in `supabase/migrations/`.
  No console-only edits (R9.2.2).

## Design tokens

Direction: **"Broadcast booth"** — dark, precise, tactile, like well-made audio
equipment. Every use of colour and motion is tied to audio state. Deliberately
the opposite of the pastel/rounded/purple-gradient AI aesthetic.

| Token | Dark (default) | Light |
|---|---|---|
| `bg` | `#0A0B0D` | `#EEF0F2` |
| `surface` | `#141619` | `#FFFFFF` |
| `surfaceRaised` | `#1C1F24` | `#F6F8FA` |
| `ink` | `#EDEEF0` | `#101215` |
| `muted` | `#8A9099` | `#5C636B` |
| `line` | `#22262B` | `#DCE0E4` |
| `signal` (brand) | `#FFB627` | `#8A5A00` |
| `live` (recording only) | `#FF3B2F` | `#D62B1F` |
| `good` | `#3DD68C` | `#0F7A4C` |

- `signal` amber = active states, primary actions, waveform at rest.
  `live` red appears **only** when the mic is actively capturing. That
  distinction is diegetic: a user should be able to tell from across the room
  whether the mic is hot. Never use red decoratively.
- No screen is more than 10% accent by area. No gradients, except one vertical
  amber-to-transparent falloff inside the waveform.
- Every pair must pass WCAG AA (4.5:1 body, 3:1 large/UI) in both modes,
  verified programmatically, table committed to `/qa/`.

**Type** — three variable families, under 900KB total:

- **Newsreader** (serif) — AI transcript, session headlines, report numbers.
  Rendering the AI's words as a serif transcript is the app's typographic
  signature: an interview in print, not a chat bubble.
- **General Sans** — UI, buttons, labels, user transcript lines.
- **Geist Mono** — timers, durations, counts, pace, dates.

Scale: display 56/40/30, title 24/20, body 17/15, label 13, micro 11. The gap
between body and display is deliberate; do not fill it. Newsreader 300 only at
≥30sp; nothing under 20sp is lighter than 400. Support OS text scale to 200%
with no clipping.

**Shape/space:** 4dp grid; spacing 4/8/12/16/24/32/48/64. Radii 10 controls,
18 cards, 28 sheets, full for pills and the waveform button. Elevation via 1dp
`line` borders; one soft shadow, reserved for sheets and the floating session
control. No shadow on flat cards.

**Chat rendering** (R7.4): AI turns are **not bubbles** — full-width typeset
Newsreader paragraphs with a thin `signal` rule on the left. User turns are
compact right-aligned `surfaceRaised` bubbles in General Sans. The asymmetry is
the identity: the AI is publishing, the user is speaking. Streaming reveals by
word, not character, with no cursor artefact and no layout jump.

**The Waveform** (R7.5) is the signature element and one `CustomPainter`. It is
the live amplitude visual, the record button, the loading state, the playback
scrubber, the history row thumbnail, and the app icon shape. All uses are
literally the same code. Never add a second visualization style, and never use
a spinner where the waveform can idle.

**Motion:** 120ms state feedback, 220ms transitions, 380ms session entry; one
`easeOutCubic`-family curve defined once in the theme. The session screen
expands from the pressed control — it does not slide in. Respect reduce-motion:
transitions become 100ms fades, the waveform becomes a static level bar,
nothing animates position.

**Copy:** plain, direct, a little dry. Buttons say what happens ("Start
speaking", "End session"). Errors state cause and fix. No exclamation marks, no
emoji in UI copy, no "AI-powered", no congratulating the user for existing.

## Never-do list (PRD §16)

- No secrets in the client, ever. No client-trusted entitlements.
- No paid or card-required service. Free tier without a credit card, or it is
  out of scope by definition — the owner's only permitted cost is the one-time
  Play registration fee.
- No image generation. No ads.
- No dark patterns: no fake urgency, no fake discounts, no hard-to-cancel
  flows, no guilt-based streak copy.
- No purple gradients, glassmorphism, or 3D blobs.
- No Poppins, Inter, Roboto, Urbanist, Montserrat, or Space Grotesk.
- No spinner where the waveform can idle instead.
- No storing session audio. No storing sensitive personal categories (R5.2.4):
  health, religion, politics, sexual orientation, finances, government ID,
  exact addresses, third parties.
- No `print()` in release. No `BuildContext` in services.
- No feature that only works on a fast phone on fast internet.
- No invented facts about the owner, no fake testimonials, ratings, or user
  counts.

## Working agreements

- Every milestone ends with a `CRITIQUE.md` entry: the three weakest things you
  just built, why, and which one you fixed before moving on. Fix at least one
  (R0.5.5).
- Before shipping any screen, ask whether it would be indistinguishable from
  any other AI app's version of it. If yes, it is not done. This bites hardest
  on chat, paywall, and settings (R0.5.6).
- SHOULD-level deviations need a code comment explaining why **and** an entry
  in `DECISIONS.md`.
- Floor before ceiling, within every milestone. Never leave a PRD requirement
  unmet to build something more interesting (R0.5.4).
- Owner decisions are marked `TODO(muneeb)` and collected in `README.md` with
  file paths. Still open: **price points** and the **second locale**. Closed:
  the app name (SpeakWise) and the package id
  (`com.muscodes.speakwise`), both settled 2026-07-28 in DECISIONS D9 — and the
  package id is permanent the moment it reaches Play.
