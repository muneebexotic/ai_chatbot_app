# Security policy

## Reporting a vulnerability

Email **muneebusman112233@gmail.com** with `SECURITY` in the subject. Include
what you found, how to reproduce it, and what an attacker gets. Expect a reply
within 7 days.

Please do not open a public issue for anything exploitable. There is no bounty;
this is a solo project. Credit is given in the release notes unless you would
rather stay anonymous.

## The one rule

**No secret ever goes in the client.** Not in Dart source, not in a committed
`.env`, not in `google-services.json`, not obfuscated, not base64'd, not split
across files and reassembled at runtime.

An Android APK is a zip. Anyone can download it, unzip it, and read every
string in it. A key in the client is a published key with extra steps. This is
not a theoretical concern for this repo — see `SECURITY-REMEDIATION.md` for the
four credentials that were public for roughly a year.

### Where things actually go

| Kind | Home | Why |
|---|---|---|
| Model API keys (Gemini), Play service account | Supabase Function secrets, server-side only | Never reaches a device |
| Supabase URL, Supabase anon key | `--dart-define` at build | Public by design; Row Level Security is what protects data, not obscurity |
| Signing keystore, `key.properties` | Local disk and CI secret store | Never in git under any circumstance |
| Transitional client keys (Milestones 0–2) | `--dart-define` | Stopgap only, and still extractable — removed when the gateway lands (PRD R9.3) |

`--dart-define` keeps keys out of *source*. It does **not** keep them out of
the *binary*. It is a way to stop leaking to GitHub while the architecture
catches up, not a security boundary. The only real fix is the gateway: the
server holds the key, the client holds a user JWT, and a stolen client
credential is worth one user's quota rather than your whole account.

## Architectural guarantees

These are enforced by design, not by convention. Breaking one is a defect.

- **All model calls go through the server gateway** (PRD §9.3). The client
  sends partner id, thread id, and user text. Model, temperature, system
  prompt, and safety settings are server-decided and not client-influenceable.
  Every client field is treated as hostile and schema-validated.
- **Entitlements are server-truth** (PRD R8.2, F2). The client displays what
  the server says and enforces nothing. A patched APK claiming Pro gets
  nothing. Play purchases are verified against the Play Developer API before
  any entitlement is written.
- **Row Level Security on every table** (PRD R9.5.1). A user reads and writes
  only their own rows. `entitlements` and `usage_daily` are service-role write
  only.
- **Session audio never leaves the device** (PRD R4.2.7). Recognition is
  on-device; only text transcripts are sent.
- **Sensitive personal categories are never stored** (PRD R5.2.4): health,
  religion, politics, sexual orientation, finances, government ID, exact
  addresses, or anything about third parties. Enforced by both a deny
  instruction in the extraction prompt and a server-side filter.

## Secret scanning

A pre-commit hook blocks credentials before they can be committed.

```bash
git config core.hooksPath .githooks     # once per clone; hooks do not clone
bash scripts/check-secrets.sh           # staged content (what the hook runs)
bash scripts/check-secrets.sh --all     # whole tracked tree (use in CI)
bash scripts/check-secrets.test.sh      # 30 cases: catches and non-catches
```

The scanner works in two tiers: credential *shapes* that can only be live keys
(`AIzaSy…`, `hf_…`, `sk-…`, private-key blocks, URLs with inline passwords),
and credential-shaped *assignments* (`secret = "<literal>"`). Identifiers like
`passwordController` do not trip it, deliberately — a hook that cries wolf gets
bypassed with `--no-verify` within a day and then protects nothing. If you
change the patterns, add a case to the test file for both what it must catch
and what it must not.

The hook is a local convenience and is bypassable by anyone who wants to. Keep
GitHub secret scanning and push protection enabled as the real backstop.

## If a secret leaks anyway

Order matters. Do not start with the git history.

1. **Revoke the credential at its provider, immediately.** Before cleanup,
   before deciding how it happened, before telling anyone. Everything else is
   optional; this is not.
2. Check the provider's usage logs for abuse.
3. Only then purge history — `SECURITY-REMEDIATION.md` has the full runbook.
4. Remember that forks, clones, caches, and code-search indexes keep their copy
   forever. Rewriting history is cleanup, never containment. The leaked value
   must be dead, not merely hidden.

Deleting the line and committing "removed key" fixes nothing. If it was ever
pushed, it is public.

## Scope

This policy covers the Kalaam client, its Supabase Edge Functions, and this
repository. Vulnerabilities in Flutter, Supabase, or Google Play should go to
those vendors.

The app is rated 13+. It stores only the data listed in PRD §9.5. Account
deletion is available in-app and removes or anonymizes server data.
