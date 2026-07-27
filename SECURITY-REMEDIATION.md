# Security remediation runbook

**Status: CONTAINED. All exposed credentials are dead. One optional
housekeeping task remains (2.5–2.6, history purge).**
Prepared 2026-07-25 as PRD Milestone 0 (§1). Implements R1.2 and R1.3.
Breach confirmed and closed out 2026-07-26.

> ## Incident record — closed 2026-07-26
>
> **The leak was exploited.** Google Cloud suspended project
> `ai-chatbot-app-22e84` for "abusive activity consistent with hijacking",
> stating that credentials were published publicly, harvested by a third party,
> and used to initiate resources in the project. This was not a near miss.
>
> **Impact: none.** Confirmed with the owner on 2026-07-26:
>
> - **No billing account was ever linked**, and billing was disabled on the
>   project. The attacker could not provision anything chargeable. Financial
>   loss is zero, and that is a fact rather than an estimate.
> - **No real users.** All accounts were the owner's own testers. No user data
>   was lost, and none needs recovering.
> - **No appeal will be filed.** PRD §2.2 already scheduled Firebase for
>   removal in Milestone 2 under the zero-cost rule; the suspension merely did
>   it early. The project is abandoned deliberately, not lost.
>
> **Credential status — all four are dead:**
>
> | | Credential | How it died |
> |---|---|---|
> | C1 | Gemini API key | project suspension |
> | C2 | Hugging Face token | auto-revoked by Hugging Face's leaked-token scanning |
> | C3 | Hugging Face token | manually deleted by owner, 2026-07-26 |
> | C4 | Firebase Android API key | project suspension |
>
> Only one Hugging Face token remained in the console; the other had already
> been killed by Hugging Face, which scans public GitHub. C1 and C4 never
> appeared in AI Studio because that page lists only imported projects, and
> theirs was suspended.
>
> **Consequence for the rebuild:** the shipped app no longer runs —
> `AppBootstrap.initialize()` calls `Firebase.initializeApp()` against a dead
> project. This is acceptable and expected. Milestone 2 becomes *build Supabase
> from scratch* rather than *migrate off Firebase*, which is less work, not
> more. The local `google-services.json` now points at nothing and is deleted
> in Milestone 2.
>
> **The remaining history purge is now housekeeping, not security.** Every
> leaked value is inert. Reasons still to do it: this is a public portfolio
> repository and `git log -S` currently shows committed keys to anyone curious;
> GitHub secret scanning will keep flagging it; and it drops ~1.4MB of junk
> blobs from every clone. Reason to do it *soon* rather than eventually: the
> rewrite gets more painful with every commit stacked on top, and right now
> there are only four.

The working tree is clean and every exposed credential is revoked. The
published git history still contains the dead key literals, and nothing in this
branch can change that — history rewriting must be run by a human, per R1.2.
The agent that wrote this file deliberately ran no history-rewriting command
and no force push.

Part 1 is the audit and the post-mortem; read it even though the incident is
closed, because 1.3 explains the mistake that caused it and 1.4 lists the one
thing still open. Part 2 is the runbook, now largely marked DONE or NOT
APPLICABLE — 2.5 and 2.6 are all that remain, and they are optional
housekeeping.

**The lesson worth keeping** is the ordering, which held up under a real
incident: revocation is what stops an attacker, and history rewriting never
was. Had this gone the other way — a linked billing account and a few hours
spent on `filter-repo` first — the outcome would have been a bill rather than a
suspension notice. It ended at zero because the keys died before the cleanup
started, not because the cleanup was thorough.

---

## Part 1 — Audit findings (R1.3)

Repository: `github.com/muneebexotic/ai_chatbot_app` (public).
Scope: every file in `git ls-files` at commit `8145cba`, plus full history.
Method: pattern sweep for `AIza`, `sk-`, `hf_`, `Bearer `, `apiKey`, `secret`,
`password`, private-key blocks, and credential-bearing URLs; plus a manual read
of every file in `lib/services/`.

Key values below are **truncated on purpose** so that this document does not
itself reintroduce a live credential into the new history. Recover full values
locally before you purge — see 2.1.0.

### 1.1 Live credentials exposed — revoke all of these

| # | Credential | Location | In history since | Exposure |
|---|---|---|---|---|
| C1 | Google Gemini API key `AIzaSyAss8…MtJY` | `lib/services/gemini_service.dart:19` | `4eaac90`, 2025-07-10 (initial commit) | **~12 months, public** |
| C2 | Hugging Face token `hf_hVyK…dcDcbv` | `lib/services/image_generation_service.dart:26` | `1f75460`, 2025-09-03 | **~11 months, public** |
| C3 | Hugging Face token `hf_VUSR…ytalqu` | `.env:1` | `1f1ccc2`, 2025-08-30 | **~11 months, public** |
| C4 | Firebase Android API key `AIzaSyDxT_…8qPOo` | `android/app/google-services.json:23` and `:68` | `4eaac90`, 2025-07-10 | **~12 months, public** — see 1.2 |

C2 and C3 are **two different Hugging Face tokens**. Revoke both. It is easy to
revoke one, see the other still listed, and assume it is the one you just
handled.

**C3 has already been "fixed" once and came back.** History shows the exact
sequence, all on 2025-09-03:

```
3f0669b  Implement secure API key management with flutter_dotenv
e6b9299  Remove .env from git tracking          <- the fix
1ba7f0c  fix                                    <- .env returns, still tracked
```

The reason it came back is root-caused in 1.3. If you do not fix that cause,
this will happen a third time.

### 1.2 Firebase API key (C4) — real, but a different kind of problem

Do not treat C4 like C1–C3, and do not panic about it. Android Firebase API
keys are designed to ship inside the APK; Google documents them as project
identifiers, not authorization secrets. Anyone who downloads your app has this
key whether or not it is in git. Access is controlled by Firebase Security
Rules, not by key secrecy.

It still needs action, because an **unrestricted** key is abusable: it can be
used to hit Identity Toolkit (sign-up/sign-in endpoints), burn project quota,
and reach any other Google API enabled on the project. So:

- **Restrict it** (2.4). Rotating without restricting achieves nothing.
- Rotate it only if it was ever reused for a non-Firebase Google API.

Also in `google-services.json`, and also not secret but worth knowing is now
public: project number `630453425342`, project id `ai-chatbot-app-22e84`, three
OAuth client IDs, and two release signing-certificate SHA-1 hashes.

The file is now untracked and gitignored (R1.4). Your local copy is untouched
so the Android build still works.

### 1.3 Root cause: `.gitignore` was byte-corrupted

`.env` was tracked despite a `.env` line in `.gitignore`. The line was written
by PowerShell redirection (`>` or `Add-Content`), which defaults to **UTF-16LE**
in Windows PowerShell 5.1. The last bytes of the old file were:

```
2E 00  65 00  6E 00  76 00      ->  '.' NUL 'e' NUL 'n' NUL 'v' NUL
```

Git reads `.gitignore` as bytes. It looked for a path literally named
`.\0e\0n\0v`, which never matched `.env`. The rule was present, looked correct
in most editors, and did nothing. Commit `e6b9299` untracked the file, and
because the ignore rule was inert, the next `git add -A` in `1ba7f0c` put it
straight back.

Fixed in this branch: `.gitignore` is rewritten as UTF-8 without a BOM, with a
header warning about the encoding trap. If you add rules from PowerShell, use
`Add-Content .gitignore 'rule' -Encoding utf8`.

### 1.4 Not a secret, but abusable — decide before Milestone 1

`lib/services/cloudinary_service.dart:9-10` hardcodes cloud name `drbt1cndv`
with **unsigned** upload preset `unsigned_preset`. Unsigned presets are meant
to be client-visible, so this is not a leaked credential. It is an open,
unauthenticated upload endpoint into your Cloudinary account that anyone can
now find and script against, for storage-quota exhaustion or to host arbitrary
content under your account.

PRD §2.2 removes Cloudinary entirely in favour of Supabase Storage. Until that
lands, either delete the unsigned preset in the Cloudinary console or add
upload restrictions to it. Left alone, it is the most likely thing here to be
abused next, because it needs no stolen key at all.

### 1.5 Lower severity — no action needed in Milestone 0

- **PII in logs.** 200 `print()` calls in `lib/` survive into release builds.
  None print a token, password, or API key — checked. Several print Firebase
  UIDs (`auth_provider.dart:176,196,210`, `firestore_service.dart:41,74,85,846`,
  `payment_service.dart:189`) and obfuscated emails. On Android these reach
  logcat, readable by other apps holding `READ_LOGS` and by anyone with adb.
  Resolved by the `Log` utility in Milestone 1 (PRD §2.2), which no-ops in
  release.
- **`flutter_lints` is misindented in `pubspec.yaml:59`.** It sits at the top
  level instead of under `dev_dependencies`, so lint rules are not applied and
  `flutter analyze` is weaker than it looks. Not a security issue; fix it in
  Milestone 1 when §14 requires a clean analyze.
- **No `flutter_dotenv` dependency exists.** The committed `.env` was never
  read by the app. It leaked a live token while providing nothing — which is
  why it went unnoticed for eleven months. Replaced by `.env.example`
  (names only, no values) plus `--dart-define`.

### 1.6 Result of the sweep

Zero credentials remain in tracked files. Verify at any time:

```bash
bash scripts/check-secrets.sh --all
```

This is a statement about the **current tree only**. History is unchanged until
you complete Part 2.

---

## Part 2 — Owner runbook (manual)

Do not delegate these to an agent. Every step below either destroys data or
touches a live account.

### 2.0 Before you start

- Do this in one sitting. A half-purged repo with live keys is the worst state.
- **Make a backup first**: `git clone --mirror https://github.com/muneebexotic/ai_chatbot_app.git ai_chatbot_app-backup.git`
  Keep it offline until you have confirmed the rewrite is good. It contains the
  live secrets — delete it once you are done.
- Tell any collaborator to stop pushing until you say otherwise.

### 2.1 Revoke and regenerate every exposed credential — DO THIS FIRST

> **DONE, 2026-07-26.** All four credentials are dead: C1 and C4 with the
> project suspension, C2 auto-revoked by Hugging Face, C3 deleted by the owner.
> Kept below as the record of what was done and as the procedure for next time.

Assume all four keys are already compromised. Automated scanners harvest public
GitHub within minutes of a push; C1 has been readable for roughly a year. The
absence of a surprise bill is not evidence of no abuse — free tiers fail
silently by throttling, not by charging.

**2.1.0 Recover the full values first** (you need them to identify the right
keys in each console, and after the purge they will be gone from your history):

```bash
git grep -h -o -E 'AIzaSy[0-9A-Za-z_-]{33}|hf_[0-9A-Za-z]{30,}' $(git rev-list --all) \
  | sort -u
```

Save that output to a scratch file **outside the repo**. Delete it at 2.7.

**2.1.1 Gemini key (C1)** — <https://aistudio.google.com/apikey>
Delete the key ending `MtJY`. Create a replacement. Before leaving, check
usage on the project for traffic you did not generate.

**2.1.2 Hugging Face tokens (C2 and C3)** — <https://huggingface.co/settings/tokens>
Revoke **both** tokens (`hf_hVyK…` and `hf_VUSR…`). Do not reissue: PRD §2.2
cuts image generation entirely, so nothing in the rebuild needs a HF token.

**2.1.3 Any other provider** — the `.env` also listed `OPENAI_API_KEY` and
`STABILITY_API_KEY`, both with placeholder values (`your_..._here`). No live
key was committed for either. Nothing to revoke; confirm you never replaced
those placeholders locally and pushed.

**2.1.4 New keys go nowhere near the repo.** Pass them at build time:

```bash
flutter run --dart-define=GEMINI_API_KEY=<new key>
```

This is a stopgap for Milestones 0–2 only. A key in an APK is extractable by
anyone who downloads it, so `--dart-define` is *not* a fix — it is a way to
keep the app running until the gateway (PRD R9.3) holds the key server-side and
the client holds none. Do not let it become the permanent answer.

### 2.2 Rotate Google / Firebase service credentials

> **NOT APPLICABLE.** No service-account key was ever committed (verified). The
> project is suspended and abandoned; there is nothing left to rotate.

- **Firebase Android API key (C4)**: see 2.4 — restrict rather than rotate,
  unless it was reused elsewhere.
- **Service account keys**: none were committed (verified). If you have ever
  downloaded a service-account JSON for this project, check it is not sitting
  in another repo, in a chat, or in your Downloads folder. The Play Developer
  API service account required for R8.2 does not exist yet — when you create
  it, it goes in Supabase Function secrets, never in git.
- **OAuth client IDs** in `google-services.json` are public by design. No
  action.
- **Signing certificate hashes** are public by design. No action. But if the
  upload keystore itself was ever committed anywhere, that is a separate
  emergency — it was not committed here.

### 2.3 Check for abuse before you assume you got away with it

> **DONE, 2026-07-26 — abuse confirmed, impact zero.** Google detected the
> hijacking and suspended the project. No billing account was ever linked, so
> nothing chargeable could be provisioned. No real users, no data lost. This
> section is exactly why the check is in the runbook: the abuse was real and
> would not have shown up as a bill.

- Google Cloud console → APIs & Services → Metrics for project
  `ai-chatbot-app-22e84`. Look for request spikes outside your own usage.
- Firebase console → Authentication → Users. Look for accounts you cannot
  account for; an unrestricted key plus open sign-up is the standard
  free-tier-farming pattern.
- Firestore usage graphs for read/write spikes.
- Hugging Face account activity.
- Cloudinary console → usage, and the media library for content you did not
  upload (see 1.4).

Record what you find. If anything looks abused, rotate that provider's
credentials again *after* the purge, since the old values stay readable in
forks (2.6).

### 2.4 Restrict the Firebase API key

> **NOT APPLICABLE.** The key died with the project suspension. Firebase is
> being removed entirely in Milestone 2 (PRD §2.2), so no replacement key will
> exist to restrict.

Google Cloud console → APIs & Services → Credentials → the `AIzaSyDxT_…` key:

- **Application restrictions** → Android apps → add package name
  `com.muneeb.aichatbot` with its release SHA-1.
- **API restrictions** → restrict to only the APIs the app actually calls
  (Identity Toolkit, Firestore, Storage). Never leave it unrestricted.

Note that PRD §2.2 removes Firebase entirely in Milestone 2 for zero-cost
reasons. Restrict the key now anyway — Milestone 2 is not today, and the key is
live in every APK already shipped.

### 2.5 Purge the history

> **OPTIONAL — housekeeping, not security.** Every leaked value is already
> dead. Do this for repository hygiene and to stop GitHub secret scanning
> flagging the repo. Cheapest done now, while only a handful of commits sit on
> top of the rewrite.

Only now. Revocation is done, so a leaked-but-dead key is a cleanliness problem
rather than a live one.

**Preferred: `git filter-repo`.** `git filter-branch` is deprecated, slow, and
easy to get wrong.

**Merge the Milestone 0 branch to `main` and push it BEFORE you purge.**

This ordering is not optional and it is easy to get backwards. The purge
rewrites every commit in the repository. If the Milestone 0 work is still
sitting only on your machine when you rewrite, its commits will be based on
parents that no longer exist, and you will be resolving that by hand
afterwards. Merge first and the purge simply carries the fix along with
everything else.

```bash
git checkout main
git merge --no-ff milestone-0-security-remediation
git push origin main
```

Yes, this pushes the branch while the old keys are still in history. That
changes nothing: they have been public for a year, and by this point 2.1 has
already killed them. There is nothing left to protect by waiting.

```bash
# Install (once)
pip install git-filter-repo
# or: brew install git-filter-repo   |   winget install git-filter-repo
```

Work on a **fresh mirror clone**, not on your working checkout — filter-repo
refuses to run on a repo with a remote, by design:

```bash
cd ..
git clone --mirror https://github.com/muneebexotic/ai_chatbot_app.git purge.git
cd purge.git
```

Create `../replacements.txt`. **Paste the real full key values** from 2.1.0 —
they are deliberately not written here so that this committed file does not
carry live secrets:

```
<full Gemini key from 2.1.0>==>REDACTED-GEMINI-KEY
<full HF token C2 from 2.1.0>==>REDACTED-HF-TOKEN
<full HF token C3 from 2.1.0>==>REDACTED-HF-TOKEN
<full Firebase key from 2.1.0>==>REDACTED-FIREBASE-KEY
```

Then run both operations in one pass — delete the files that should never have
existed, and redact the literals inside files that must stay:

```bash
git filter-repo \
  --invert-paths \
    --path .env \
    --path all-files.txt \
    --path my-changes.patch \
    --path project_structure.text \
    --path android/app/google-services.json \
    --path-glob 'android/build/*' \
    --path-glob '**/.dart_tool/*' \
  --replace-text ../replacements.txt
```

Verify before pushing anything — this is the step people skip:

```bash
# Expect: no output.
git grep -I -n -E 'AIzaSy[0-9A-Za-z_-]{33}|hf_[0-9A-Za-z]{30,}' $(git rev-list --all)

# Expect: no output.
git log --all --name-only --format='' -- .env all-files.txt my-changes.patch \
  project_structure.text android/app/google-services.json | sort -u

# Expect: REDACTED-GEMINI-KEY appears where the key used to be.
git show 4eaac90:lib/services/gemini_service.dart | grep -n REDACTED || true
```

If any of those return results, **stop and do not push**. Re-run with corrected
patterns.

### 2.6 Force push, and understand what it does not fix

```bash
git remote add origin https://github.com/muneebexotic/ai_chatbot_app.git
git push --force --mirror origin
```

`--mirror` rewrites branches **and tags**. A purge that leaves an old tag
pointing at a pre-rewrite commit leaves the secret reachable, which is the
usual way this fails.

Then, and this is the part that gets skipped:

- **Every existing fork and clone still contains the original secrets.** You
  cannot rewrite anyone else's copy. This is exactly why 2.1 comes first and
  why "I purged the history" is never containment.
- **GitHub keeps unreachable objects reachable by SHA.** A pre-rewrite commit
  URL can stay resolvable through cached views and the API. Open a GitHub
  Support request asking them to garbage-collect the repository and purge
  cached views. Until they do, the old blobs may still be fetchable.
- **Open PRs hold their own copies.** Close any open PR or fork PR referencing
  the old history.
- **Third-party mirrors** — anything that ingested the repo (CI caches, code
  search indexes, archive sites) retains its copy indefinitely.

Nothing on this list is fixable by you. All of it is survivable **only because
the keys are already dead** from 2.1.

### 2.7 Close out

- Delete the scratch file of recovered key values from 2.1.0, and
  `../replacements.txt`.
- Delete the mirror backup from 2.0 once the rewrite is confirmed good.
- Re-clone fresh, and tell every collaborator to delete their clone and
  re-clone. A stale clone that gets pushed will resurrect the entire old
  history.
- Enable the hook in the new clone:

  ```bash
  git config core.hooksPath .githooks
  bash scripts/check-secrets.sh --all
  ```

- Turn on GitHub secret scanning and push protection: repo → Settings → Code
  security. Free for public repos. It is a backstop for the local hook, which
  anyone can bypass with `--no-verify`.
- Update this file's status header to COMPLETE, with the date and what you
  found in 2.3.

---

## What this branch already did (no action needed)

| Req | Change |
|---|---|
| R1.1 | Hardcoded Gemini key removed from `gemini_service.dart`; HF token removed from `image_generation_service.dart`; both now read `String.fromEnvironment`. `.env` deleted and untracked. |
| R1.3 | Full-tree secret sweep; findings in Part 1. Zero credentials remain in tracked files. |
| R1.4 | `.gitignore` rewritten as UTF-8 (no BOM) covering `.env*`, `build/`, `.dart_tool/`, `android/local.properties`, `google-services.json`, `GoogleService-Info.plist`, `*.jks`, `*.keystore`, `*.patch`. |
| R1.5 | Deleted `all-files.txt`, `my-changes.patch`, `project_structure.text`, and the tracked build artifact `android/build/reports/problems/problems-report.html`. |
| R1.6 | `SECURITY.md`, `scripts/check-secrets.sh`, `scripts/check-secrets.test.sh` (30 cases, passing), `.githooks/pre-commit`. |
| — | `.env.example` documenting names with no values (R9.6). |

Deliberately **not** done here, per R1.2: no `git filter-repo`, no
`filter-branch`, no `git push --force`, no credential revocation. Those are
Part 2 and they are yours.
