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

**Kalaam** — a voice-first AI you speak to, which reports back on how you
sounded. Not a chat wrapper. A Session (live spoken conversation → report) is
the product; typed chat is the quiet half.

The loop that pays: speak → report → weak spot → return tomorrow → hit the free
minute cap → subscribe. Retention and monetization are the same loop, which is
why the report is the flagship.

## Current state — read this before believing any file

This is a **rebuild in progress on a live codebase**, not a greenfield project.
The repo currently contains the *old* app. Only Milestone 0 is done.

| | Now | Target (PRD) |
|---|---|---|
| State | Riverpod (state classes still `ChangeNotifier`, D5) | Riverpod `Notifier` throughout |
| Auth | **Supabase** (M2 done) | Supabase |
| Data | Firestore for chat/conversations only | Supabase Postgres + RLS |
| Model calls | Direct from client | Server gateway only, key server-side |
| Layout | `lib/screens|providers|services|…` | `lib/app|core|design|features/*|l10n` (PRD §13) |
| Type | Poppins + Urbanist | Newsreader + General Sans + Geist Mono |
| Errors | `null` returns | `Result<T>` / sealed `AppFailure` |
| Images | Generation (DALL·E/HF/Stability) | Understanding only, via gateway |

**`.kiro/steering/*.md` describes the OLD architecture** (Provider, Firebase,
Poppins). It is stale and contradicts the PRD. Do not follow it; the PRD wins.
Delete or rewrite it in Milestone 1.

Milestone status: **0, 1, 2 done.** 3–8 not started. Do them in order
(PRD §15); the order is a closed ceiling.

What M2 landed: schema + RLS on both projects with an RLS test per table,
Supabase auth (email/password and Google), account deletion via Edge Function,
package renamed to `com.muscodes.kalaam`. What it deliberately did not: usage
counters and entitlements are still local on `PaymentService`, because
`usage_daily` and `entitlements` are service-role write only and the gateway
that writes them is M3 (CRITIQUE W2.2).

## Stack

- Flutter 3.38.6 / Dart 3.10.7 (SDK constraint `^3.8.1`)
- Riverpod for state and DI — services never touch `BuildContext`
- Supabase: Auth, Postgres with RLS, Edge Functions (Deno/TypeScript), Storage
- Drift (SQLite) for local threads/messages/sessions/reports;
  `shared_preferences` for settings only
- `speech_to_text` and `flutter_tts` — both **on-device**. This is the whole
  business model: a spoken minute costs zero, so voice practice is free to run
  for a solo developer and expensive for a funded competitor. Never replace
  either with a cloud service.
- `gpt_markdown` — the single markdown renderer. Not `markdown`,
  `flutter_markdown`, `markdown_widget`, or `flutter_highlight`.
- Targets: **Android first, iOS kept compiling.** No web, Windows, macOS, or
  Linux — those folders get deleted in Milestone 1.

## Commands

```bash
flutter pub get
flutter analyze                     # must be clean, no ignored rules (§14)
flutter test
flutter test --coverage             # domain + application ≥70% (§14)
# Supabase config is required. Point it at kalaam-dev while developing.
flutter run --dart-define=GEMINI_API_KEY=<key> \n  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \n  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...

flutter test                        # 80 offline; integration tests self-skip
flutter test --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
                                    # +24 against kalaam-dev (RLS + auth)

npx supabase link --project-ref <ref>   # dev: sbwaiindthrluqoypvqc
npx supabase db push                    # prod: kneiwapwjuuaxcenlfsu
npx supabase functions deploy delete-account
flutter build apk --split-per-abi   # per-ABI under 30MB (R11.1)

bash scripts/check-secrets.sh       # staged content; runs from pre-commit
bash scripts/check-secrets.sh --all # whole tracked tree; use in CI
bash scripts/check-secrets.test.sh  # 30 cases, must stay green
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
- `--dart-define` keeps keys out of *source*, not out of the *binary*. It is a
  Milestone 0–2 stopgap. The fix is the gateway (R9.3): server holds the key,
  client holds a user JWT.
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
  `l10n/` ARB files from day one (R11.7).
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
  file paths. Open ones: final app name, package id (currently
  `com.example.ai_chatbot_app`, which **cannot be published to Play**), price
  points, second locale.
