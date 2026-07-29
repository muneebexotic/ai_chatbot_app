# Milestone 4 — device pass

Evidence for PRD §14. Companion to `m3-device-pass.md`.

**Device:** OnePlus 9 (LE2115), Android 14 / API 34, 1080×2400, wireless adb.
**Build:** debug, `--split-per-abi` arm64, `--dart-define` at `kalaam-dev`.
**Date:** 2026-07-29.

> **Status: rounds 1 and 2 done, a third owed.** The session now runs — round 2
> confirmed it reaching `Listening` with the timer ticking and all three live
> indicators lit. R4.2.3 (barge-in) and R4.2.4 (latency) are still **not
> measured**, because both need a human voice and the agent driving this cannot
> speak into the phone. Those two are the milestone's headline requirements and
> they remain open; see CRITIQUE W4.1.

---

## Getting the app onto the phone, which cost more than it should have

Three traps, all environment rather than code, recorded so the next pass does
not pay again.

**The wireless-debugging address rotates, and the IP can move too.** The saved
note says a stale port gives `device offline` on install while `adb devices`
still reports `device`. It did — and the phone had also moved network
(`192.168.2.102` → `192.168.137.192`). `adb mdns services` finds the current
host *and* port; nothing else does.

**`flutter run` cannot see a device connected under its mDNS name.** The
advertised name was `adb-ab78744b-fx0qec (2)._adb-tls-connect._tcp`, and
Flutter truncates at the space — `flutter devices` reported
`Android null (API null) (unsupported)`. Reconnecting with
`adb connect <ip>:<port>` gives a space-free serial and Flutter then reports
`android-arm64 • Android 14 (API 34)`.

**The debug APK is 155MB and the link ran at 1.0 MB/s, degrading to 0.2.**
`flutter run` timed out installing twice, and `adb install` failed after seven
minutes with an empty error. What worked:

```
flutter build apk --debug --split-per-abi     # 91MB arm64-only
adb push <apk> /data/local/tmp/sw.apk         # via PowerShell: Git Bash
adb shell pm install -r -t /data/local/tmp/sw.apk   # mangles the device path
flutter attach -d <ip>:<port>
```

`flutter run --target-platform` does not exist in Flutter 3.38.6.

**`dart:developer` output did not reach the `flutter attach` console.** No `Log`
line appeared at any level, so the microphone failure had to be diagnosed by
reading rather than by reading logs. The existing note that Dart logs never
reach logcat now has a second half: they may not reach `attach` either. A debug
logcat sink would have saved an hour and is not written.

---

## What was verified

### R4.1.1 — the session home *(screenshot 07)*

One primary action, "Start speaking". Partner rail with generated marks from the
one painter (R7.5.3). Free Talk first, so D4's ordering fix from Milestone 3
still holds. History empty state reads "No sessions yet. The first one takes 60
seconds." — §7.6's own worked example, verbatim.

The heading renders in Newsreader. This is the first screen in the app where the
typographic signature (§7.2) is actually visible.

### R4.1.3 — the brief *(screenshot 08)*

Partner mark, name, description, "How it opens", and the optional one-line goal
with its 0/200 counter.

### R4.1.2 and R4.2.7 — the first-run flow *(screenshots 09–13)*

Three steps as specified: permission with a plain explanation, a five-second
level check with a live waveform, and the 5/10/20/open-ended choice.

R4.2.7's claim is on the permission step, in its own bordered block with a
`good`-green lock — "Your voice stays on this phone… No audio is recorded,
uploaded, or stored. Only the text of what you said is sent, so the partner can
reply." It is stated before the system dialog appears, which is the moment it is
worth something.

### R7.1.1 — the live-microphone indicator, all three channels *(screenshot 11)*

The calibration screen showed **real microphone amplitude**: a genuine voice
envelope, not the synthesised idle wave. Simultaneously:

* colour — `live` red bars
* shape — the record dot
* text — the `LIVE` label

On completion it switched to amber `static_`, dropped the dot and the label, and
reported "That came through clearly." in `good` green. The full chain — mic
permission → recogniser → `onSoundLevelChange` → `AmplitudeWindow` → painter —
works on device.

### R4.2.1 — the live session screen *(screenshot 14)*

Partner name, state label, mono elapsed timer, waveform, and exactly three
controls. No `AppBar`.

### R4.2.6 — force-kill recovery *(screenshot 16)*

`am force-stop` mid-session, then relaunch. The home surfaced "A session ended
unexpectedly", from the local Drift row with no `ended_at`. The recovery path
fired unprompted, which is the requirement working rather than a test of it.

---

## Round 2 — the session runs

After the round-1 fixes, a second install confirmed:

* **D1 fixed** — the first-run flow is skipped; Start goes straight from the
  brief into the session.
* **D3 fixed** — the partner mark renders at its intended 72dp on the brief.
* **D4 fixed** — "Conversation Partner" reads in full on two lines.
* The tolerant column read works: partners load against a database that does
  **not** have `opening_line`, which is the state dev is in.
* **The live session reaches `Listening`** with the timer ticking (00:16
  observed), the `LIVE` label, the record dot, red bars, and Android's own
  microphone indicator lit in the status bar.

Then three more things were wrong.

---

## Eight defects found by looking, none reachable by the suite

The pattern from CRITIQUE W2.1, for the fourth milestone running. D1–D5 are
fixed in `a74609d`; D7 in the audio-focus commit; D8 is fixed; D6 and D9 are
open and named.

### D1 — R4.1.2's first-run flow ran before every session *(BLOCKING, fixed)*

`SessionSettings` returned a synchronous default and loaded from disk
asynchronously. `SessionBriefScreen` reads it the instant Start is tapped, which
is usually the provider's first read, so `hasCompletedFirstRun` was `false`
every time.

A synchronous default is safe only when it is indistinguishable from the loaded
value. A first-run flag is the opposite of that by definition. Preferences are
now awaited in `main()` and injected.

### D2 — the microphone died the moment the session opened *(BLOCKING, fixed)*

Every session paused instantly with "The microphone stopped responding", and
Resume did not recover it. Android's `SpeechRecognizer` is one system service
and does not tear down synchronously; the calibration step stops it and the
session opens it a fraction of a second later, which returns
`ERROR_RECOGNIZER_BUSY` — reported by `speech_to_text` as **permanent**, so the
controller paused forever. D1 made it fire on every session rather than only the
first.

Fixed twice over, because either fix alone is a coin flip: the service waits for
the platform to settle after a stop or cancel, and a short list of transient
codes is no longer treated as permanent regardless of what the plugin says.

### D3 — the partner mark stretched across the whole screen *(fixed)*

`SizedBox(width: 72)` inside a `ListView` does nothing. **This is
`m3-device-pass.md` D2 exactly, in new code.** It renders correctly in the
horizontal rail (width-bounded items) and wrongly on the brief screen (vertical
list), which is why reading the code does not catch it. See CRITIQUE W4.2 — the
instance is fixed, the class is not.

### D4 — every partner name on the rail was truncated *(fixed)*

"Conversation ...", "Inte...". One line at 168dp cannot hold "Conversation
Partner". The widget test asserted the card existed, not that its label
survived.

### D5 — "How it opens" repeated the description verbatim *(fixed, needs migration)*

R4.1.3 wants an example opening line; the placeholder returned
`partner.description`, so the brief showed one sentence twice. Fixed as data —
a new `partners.opening_line` column seeded for all five built-ins — because
§5.3.2 ships partners as rows and a Dart constant would go stale invisibly.

**Not yet applied.** `supabase db push` needs `SUPABASE_DB_PASSWORD`.

### D6 — the recovered-session notice offers an empty transcript *(open)*

A session force-killed before its first turn shows "0 minutes were saved. You
can still see the transcript." Offering a transcript with nothing in it is worse
than saying nothing. Should be suppressed when the recovered session has no
turns. Minor, and not fixed.

---

### D7 — the app lost audio focus to itself *(BLOCKING, fixed)*

With D1 and D2 fixed, every session paused instantly with a *different*
message: "Something else took the audio."

`MainActivity` requested `AUDIOFOCUS_GAIN_TRANSIENT` so that
`AUDIOFOCUS_LOSS_TRANSIENT` would report an incoming call with no
`READ_PHONE_STATE` permission. What that missed is that **this app's own
components request audio focus too** — `SpeechRecognizer` takes it to listen and
`TextToSpeech` takes it to speak. The Activity's request was displaced by the
recogniser it existed to support, and the session paused before a word was
spoken.

Focus is now left to the plugins that actually play and capture. The class only
observes: `ACTION_AUDIO_BECOMING_NOISY` for headphones, and
`OnModeChangedListener` (API 31+) for a call. Below API 31 there is no
permission-free equivalent and the session still reacts through the recogniser
erroring — less precise wording, same behaviour.

### D8 — the finished session did not appear in history *(fixed)*

Ending a session returned to a home screen still reading "No sessions yet." The
row was on disk; `sessionHistoryProvider` is a `FutureProvider` that had already
resolved. A user cannot tell that apart from their session being thrown away.
`end()` now invalidates both list providers.

### D9 — the screen said "Listening" after the microphone had closed *(OPEN)*

`dumpsys audio` shows the last `rec stop` at 15:35:16 — the exact second the
screenshot showed "Listening" at 00:16. From then on the UI claimed a live
microphone that was not open.

The likely path: in hands-free mode silence ends a turn, `_finishUserTurn` finds
no text and calls `_listen()` again — but `SpeechRecognitionService.listen`
returns early when `_speech.isListening` is still true, so on a stale `true` the
restart is skipped and nothing reopens the microphone. The state machine
believes it is listening forever.

**Not fixed.** It needs the recogniser's real state rather than the plugin's
cached flag, and a watchdog that notices no level callback has arrived for a
few seconds. Both want a device to verify, which is the same round-3 trip
R4.2.3 and R4.2.4 need.

### D10 — adding a column made the whole product unreachable *(fixed)*

With the `opening_line` migration finally applied, the partner rail came back
**empty** and "Start speaking" was disabled.

Milestone 3 ran `revoke select (system_prompt) on public.partners`. A
column-level revoke cannot subtract from a table-level grant, so Postgres drops
the table-wide `SELECT` and replaces it with an explicit per-column grant for
each remaining column. That is invisible and permanent: **from that migration
onward, every column added to this table starts with no grant at all.**

So `opening_line` existed and was unreadable. And the client's own fallback did
not save it — it matched `42703` (undefined_column), while an ungranted column
returns `42501` (insufficient_privilege).

Two fixes: `grant select (opening_line)` in its own migration, and the fallback
now catches both codes. The column comment records the rule for the next person,
because nothing in the schema otherwise says that this table has no table-level
grant to inherit.

**Verified after the fix:** the rail is back and the brief shows "What is on
your mind today?" — a real opening line, distinct from the description.

---

## Still owed

* **R4.2.3 and R4.2.4 measurements.** The headline requirements. CRITIQUE W4.1.
  **Both need a human speaking into the phone** — the agent driving this pass
  cannot, so they are the owner's to run or to sit beside.
* **D9**, above, which may well be what a spoken turn hits first.
* **R11.2's 60fps trace**, committed here.
* The interruption matrix beyond force-kill: call, background, headphones,
  network.
* R10.6's crisis path exercised on the device against the scripted transcript.
* 200% text scale and the small-phone/tablet matrix — §14 puts both in the
  Milestone 8 hardening pass, and neither is claimed here.
