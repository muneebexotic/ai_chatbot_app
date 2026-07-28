# Milestone 3 — device pass

Evidence for PRD §14. Companion to `contrast-table.md` from Milestone 1.

**Device:** physical Android, 1080×2400, density 480 (override 408), over
wireless adb. **Build:** debug APK, `--dart-define` pointed at `kalaam-dev`.
**Date:** 2026-07-28.

Screens exercised: welcome, sign-up, chat empty state, chat with a streamed
reply, the loading state, the partner picker, the conversation drawer, Memory,
settings — in dark, then the chat surface and settings again in light.

---

## 1. No model key ships in the APK

The claim CRITIQUE W0.3 said Milestone 0 could not honestly make
(`--dart-define` "looks like a fix and is not"), tested against the artefact
rather than the source:

```
$ grep -a -c "gsk_"          app-debug.apk   → 0
$ grep -a -c "AIzaSy"        app-debug.apk   → 0
$ grep -a -c "api.groq.com"  app-debug.apk   → 0
$ grep -a -c "service_role"  app-debug.apk   → 0
$ grep -a -c -E "sk-[0-9A-Za-z]{20,}" app-debug.apk → 0
```

`grep -a -c "sk-"` returns 12, all Vulkan validation-layer strings
(`aspectMask-parameter`, `dstAccessMask-`, `stencilWriteMask-`). None is a
credential shape, which is why the shaped pattern above returns zero.

The provider's hostname does not appear at all. The client knows only its own
Edge Function URL, which is the operative half of R9.3.3's provider-agnostic
routing: swapping Groq for Cerebras cannot require an app release, because the
app has never heard of Groq.

## 2. Gateway, end to end

One message from the device produced, on the server: a `threads` row with a
server-derived title, a `messages` row for the user turn, a `messages` row for
the assistant turn, and an incremented `usage_daily.messages`. Time from send
to persisted reply, measured from the two `created_at` values: **0.43s**.

The R4.2.4 latency budget (1.5s to first *spoken* word) belongs to Milestone 4
and is not measured here; this is text arriving, with no text-to-speech in the
path.

## 3. Memory, end to end

A four-message thread triggered extraction. Three facts stored, all
first-person and durable:

> They are a junior developer.
> They have two years of React experience.
> They want to practice thinking out loud.

An earlier transcript that mentioned anxiety medication, a spouse, and a salary
figure stored **none** of those three categories (R5.2.4). That run exercised
the prompt half of the requirement; the filter half is covered by
`supabase/functions/tests/memory_filter_test.ts`, which asserts each of the
eight categories independently and asserts that the prompt and the filter name
the same eight.

---

## Four defects found by looking, none reachable by the suite as it stood

The pattern CRITIQUE W2.1 describes, for the third milestone running. All four
are fixed; two now have tests that would have caught them.

### D1 — every AI turn rendered at zero height *(FIXED, test added)*

`AiTurn` used `Row(crossAxisAlignment: stretch)` to place the signal rule
beside the text. `stretch` takes a tight cross-axis constraint from the Row's
own height, and a Row inside a vertical `ListView` has no bounded height to
take one from — so the turn laid out at zero and **the reply was invisible**.

The message was in state. The server had stored it. `flutter analyze` was
clean. The screen showed the user's question, a brief loading indicator, and
then nothing at all — no text, no error. The comment above the offending line
claimed the Row avoided `IntrinsicHeight`; it did, by not rendering.

Fixed by making the rule a left `Border` on the text container, which sizes
itself to the content and costs no extra layout pass. Covered by
`test/features/chat/chat_surface_test.dart`, which pumps the widget **inside a
ListView** — in a bare `Scaffold` the original code passes.

### D2 — the loading waveform drew full width *(FIXED, test added)*

`SizedBox(width: 72)` inside a `ListView` item does nothing. A list item
receives a *tight* cross-axis constraint, and `SizedBox` enforces its own
constraints within the incoming ones, so 72 clamps back up to the viewport
width. On device: fourteen fat amber pills across the whole screen.

Fixed with an `Align` to loosen the constraint first. Same test file asserts
the rendered width is 72±1.

### D3 — the idle wave was a flat bar *(FIXED)*

With D2 fixed, the waveform was compact but every bar was the same height.
`WaveformPainter` floored bar height at a fixed `2.0`, and idle amplitude tops
out at 0.22 — so on a 24dp waveform every bar computed between 0.24 and 2.64
and almost all of them flattened to exactly 2.0. §7.5.2 asks for "a calm idle
oscillation"; this was a pulsing block.

Fixed by making the floor proportional (`height * 0.03`). Invisible at the 96dp
session size, total at 24dp — which is why it survived Milestone 1's tests.

### D4 — the default partner was Debate Opponent *(FIXED)*

A brand-new account landed in the hardest partner. Two causes, one behind the
other:

1. `PartnerRepository` chained two `.order()` calls, which sends two separate
   `order=` query parameters. **PostgREST does not combine them.** Verified
   against the live project: `order=is_builtin.desc&order=difficulty.asc`
   returns Free Talk (1), Interviewer (3), Conversation Partner (2),
   Presentation Coach (3), Debate Opponent (4) — sorted on one axis and not the
   other, which is worse than unsorted because it looks sorted. A single
   `order=is_builtin.desc,difficulty.asc` is correct. Now sorted in Dart: five
   rows do not need a database sort, and a comparator in Dart cannot be
   silently wrong about it.

2. `ChatController.build()` watched `partnersProvider` to seed the default.
   `Notifier.build` re-runs when a watched provider changes and **discards the
   state it returned last time**, so any partner reload mid-conversation would
   have wiped the transcript — and the list reloads on every auth event,
   including a routine token refresh. The default is derived in
   `activePartnerProvider` now and `build()` watches nothing.

The second was never seen on screen. It was found while explaining the first.

---

## Standing, not fixed here

* **Settings still shows `+923103535835` as "Phone number".** An invented fact
  about the owner, which §16 forbids by name. It predates this milestone and
  the screen is rebuilt in Milestone 6; recorded so it is not read as real.
* **Settings is still the old surface** — amber-tinted card shadows and a
  hairline on every card, which §7.3 allows only on sheets. Inherited from
  CRITIQUE W1.1's "two things the fix made worse, kept anyway".
* **200% text scale and the small-phone/tablet screenshot matrix are not
  covered.** §14 requires both; they belong to the Milestone 8 hardening pass
  and are not claimed here.
