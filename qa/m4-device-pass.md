# Milestone 4 — device pass

Evidence for PRD §14. Companion to `m3-device-pass.md`.

**Device:** OnePlus 9 (LE2115), Android 14 / API 34, 1080×2400, over wireless
adb. **Build:** debug, `--split-per-abi` arm64, `--dart-define` pointed at
`kalaam-dev`. **Date:** 2026-07-29.

---

## Getting the app onto the phone, which is worth recording

Two traps cost real time and both are environment, not code.

**The wireless-debugging address rotates, and so does the IP.** The saved
memory says a stale port gives `device offline` on install while `adb devices`
still reports `device`. It did exactly that — and the phone had *also* moved
network, from `192.168.2.102` to `192.168.137.192`. `adb mdns services` finds
both the current host and the current port; nothing else does.

**`flutter run` cannot see a device connected under its mDNS name.** The name
advertised was `adb-ab78744b-fx0qec (2)._adb-tls-connect._tcp`, and Flutter
truncates at the space, so `flutter devices` reported `Android null (API null)
(unsupported)`. Reconnecting with `adb connect <ip>:<port>` gives a serial with
no spaces and Flutter reports `android-arm64 • Android 14 (API 34)`.

**The debug APK is 155MB and the link runs at 1.0 MB/s** (measured with `adb
push`). `flutter run` timed out installing it twice. `flutter build apk --debug
--split-per-abi` gives a 91MB arm64-only APK. `flutter run --target-platform`
does not exist in Flutter 3.38.6; the split build plus `adb install` plus
`flutter attach` is the working combination.

---

## 1. R4.2.7 — no audio leaves the device, and the UI says so

<!-- FILL: artefact grep + first-run screenshot -->

## 2. R4.1.2 — the first-run flow

<!-- FILL: permission, calibration, length -->

## 3. R4.2.1 — the live session screen

<!-- FILL: screenshots in both modes -->

## 4. R4.2.3 — barge-in

<!-- FILL: measured onset→silence, per attempt -->

## 5. R4.2.4 — end of speech to first spoken word

§14: "Latency measured: median time from end-of-speech to first spoken word,
recorded over 20 turns on 4G."

<!-- FILL: table of 20 turns, median -->

## 6. R4.2.6 — interruptions

<!-- FILL: call, background, headphones, network, force-kill -->

## 7. R10.6 — crisis response

<!-- FILL: scripted transcript on device -->

## 8. R11.2 — 60fps during a session

<!-- FILL: trace -->

## 9. §8 / F2 — the quota is the server's

<!-- FILL -->

---

## Defects found by looking

<!-- FILL -->
