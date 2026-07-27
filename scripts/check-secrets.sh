#!/usr/bin/env bash
#
# check-secrets.sh — block credentials from entering the repository.
#
# Implements PRD R1.6. Run automatically by .githooks/pre-commit; also safe to
# run by hand or in CI.
#
#   ./scripts/check-secrets.sh          scan staged content (what pre-commit does)
#   ./scripts/check-secrets.sh --all    scan every tracked file (use in CI)
#
# Requires bash (uses `read -d ''` for NUL-safe paths). Present in Git Bash on
# Windows and in every standard CI image.
#
# DESIGN NOTE — why this is not just `grep -i secret`.
# R1.3 lists `apiKey`, `secret`, `password` as search terms. Grepping those
# bare words across this repo returns 100+ hits, essentially all of them
# identifiers like `passwordController` or `validatePasswordComplex`. A hook
# that fires on every commit gets bypassed with `--no-verify` within a day and
# then protects nothing. So the checks are split into two tiers:
#
#   Tier 1 (credential shapes)  — a string that can only be a live credential.
#   Tier 2 (assignment shapes)  — `secret = "<literal>"`, i.e. the *name* says
#                                 credential AND the value is a literal, not a
#                                 variable, a build-time input, or a placeholder.
#
# Identifiers containing those words never match, because Tier 2 requires an
# assignment operator and a quoted literal immediately after the keyword.
# Every literal secret this repo actually leaked is caught — see
# scripts/check-secrets.test.sh, which asserts both the catches and the
# non-catches.

set -eu

RED=''; GREEN=''; BOLD=''; OFF=''
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
fi

SCAN_ALL=0
[ "${1:-}" = "--all" ] && SCAN_ALL=1

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM

FINDINGS="$WORK/findings"
: > "$FINDINGS"
TAB=$'\t'

# ── Paths exempt from CONTENT scanning ────────────────────────────────────
# These documents quote the patterns on purpose (the runbook must name the
# burned keys so the owner knows what to revoke). Exempt by exact path only —
# never by directory or wildcard, or the exemption becomes the hole.
is_exempt() {
  case "$1" in
    scripts/check-secrets.sh|\
    scripts/check-secrets.test.sh|\
    .githooks/pre-commit|\
    SECURITY.md|\
    SECURITY-REMEDIATION.md|\
    .env.example) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Text encoding ─────────────────────────────────────────────────────────
#
# This repository has now been damaged twice by the same trap, in two
# different ways, so it is checked rather than remembered:
#
#   1. `.gitignore` was appended to from PowerShell, which writes UTF-16LE.
#      Git read the bytes as `.\0e\0n\0v`, the rule matched nothing, and a
#      live Hugging Face token stayed tracked for eleven months.
#   2. A migration script round-tripped five Dart files through
#      `Get-Content` without `-Encoding utf8`, which decodes UTF-8 as the
#      ANSI codepage. Every em-dash became `a€"`.
#
# Both are invisible in most editors, which is exactly why they survive.
#
# NUL bytes in a text file mean UTF-16/UTF-32 was written where UTF-8 was
# expected. The mojibake markers are the UTF-8 encodings of U+00C2/U+00C3
# followed by a continuation byte — the signature of text that has been
# encoded twice.
check_encoding() {
  local path="$1" blob="$2" total stripped
  case "$path" in
    *.png|*.jpg|*.jpeg|*.gif|*.ico|*.ttf|*.otf|*.woff|*.woff2|*.jks|*.keystore|*.aab|*.apk|*.so|*.zip|*.pdf)
      return 0 ;;
  esac
  [ -f "$blob" ] || return 0

  # NUL check runs FIRST and without a binary guard, on purpose. `grep -I`
  # classifies a UTF-16 file as binary, so guarding on it above would skip
  # precisely the case this exists to catch — which is how the first version
  # of this function passed its own test.
  #
  # Counted with `tr` rather than matched with grep because a NUL cannot be
  # put in a shell variable, and `grep -P` is not available everywhere (it
  # fails outright in some locales on Git Bash).
  total=$(wc -c < "$blob" | tr -d ' ')
  stripped=$(LC_ALL=C tr -d '\000' < "$blob" | wc -c | tr -d ' ')
  if [ "$total" != "$stripped" ]; then
    printf '%s\t-\tENCODING\tNUL bytes present: UTF-16 written where UTF-8 was expected\n' \
      "$path" >> "$FINDINGS"
    return 0
  fi

  # No NULs, so grep will treat the file as text from here.
  # ANSI-C quoting gives grep the literal bytes without needing -P.
  if LC_ALL=C grep -q $'\xc3\xa2\xe2\x82\xac' "$blob" 2>/dev/null ||
     LC_ALL=C grep -q $'\xc3\xa2\xc2\x80' "$blob" 2>/dev/null ||
     LC_ALL=C grep -q $'\xc3\x83\xc2' "$blob" 2>/dev/null; then
    printf '%s\t-\tENCODING\tmojibake: UTF-8 decoded as ANSI and re-encoded (use Get-Content -Encoding utf8)\n' \
      "$path" >> "$FINDINGS"
  fi
  return 0
}

# ── Filenames that must never be committed at all ─────────────────────────
check_filename() {
  local path="$1"
  case "$path" in
    .env.example) return 0 ;;
    .env|.env.*|*/.env|*/.env.*)
      printf '%s\t-\tFILENAME\tenv file (may hold credentials; use --dart-define)\n' "$path" >> "$FINDINGS" ;;
    *.jks|*.keystore|*.p12|*.pem|*.p8)
      printf '%s\t-\tFILENAME\tsigning key / certificate material\n' "$path" >> "$FINDINGS" ;;
    google-services.json|*/google-services.json|*/GoogleService-Info.plist)
      printf '%s\t-\tFILENAME\tplatform config carrying project API keys\n' "$path" >> "$FINDINGS" ;;
    key.properties|*/key.properties|local.properties|*/local.properties)
      printf '%s\t-\tFILENAME\tlocal build config (often holds signing secrets)\n' "$path" >> "$FINDINGS" ;;
    *service-account*.json)
      printf '%s\t-\tFILENAME\tGoogle service account key\n' "$path" >> "$FINDINGS" ;;
  esac
  return 0
}

# ── Tier 1: credential shapes ─────────────────────────────────────────────
# Format: <ERE pattern>~<human label>
# Separator is `~` because `|` appears inside several of the patterns.
TIER1='AIzaSy[0-9A-Za-z_-]{33}~Google API key (Gemini / Firebase / Maps)
hf_[0-9A-Za-z]{30,}~Hugging Face access token
sk-ant-[0-9A-Za-z_-]{20,}~Anthropic API key
sk-[0-9A-Za-z]{20,}~OpenAI-style secret key
sk_(live|test)_[0-9A-Za-z]{20,}~Stripe secret key
ghp_[0-9A-Za-z]{36}~GitHub personal access token
gho_[0-9A-Za-z]{36}~GitHub OAuth token
github_pat_[0-9A-Za-z_]{50,}~GitHub fine-grained PAT
xox[baprs]-[0-9A-Za-z-]{10,}~Slack token
AKIA[0-9A-Z]{16}~AWS access key id
ASIA[0-9A-Z]{16}~AWS temporary access key id
-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----~private key block
cloudinary://[0-9]+:[0-9A-Za-z_-]+~Cloudinary credentials URL
eyJhbGciOi[0-9A-Za-z_-]{20,}~JWT (may be a signed service token)
Bearer [0-9A-Za-z_.-]{25,}~hardcoded bearer token
postgres(ql)?://[^:@/[:space:]]+:[^@[:space:]]+@~database URL with inline password
mongodb(\+srv)?://[^:@/[:space:]]+:[^@[:space:]]+@~MongoDB URL with inline password'

# ── Tier 2: assignment shapes ─────────────────────────────────────────────
# Keyword, then `=` or `:`, then a quoted literal of >=8 chars.
# Requiring the operator is what excludes `passwordController`, `passwordHint`,
# `validatePassword`, `errors['password']`, and every other identifier.
TIER2_KEYS='api_?key|apikey|secret|client_secret|password|passwd|access_token|auth_token|refresh_token|private_key|service_role'
TIER2_RE="(${TIER2_KEYS})[\"']?[[:space:]]*[:=]+[[:space:]]*[\"'][^\"']{8,}[\"']"

# Values that are obviously not live credentials.
TIER2_ALLOW='your_|_here|YOUR_|placeholder|example|EXAMPLE|changeme|CHANGEME|xxxx|XXXX|<[^>]*>|\$\{|\$[A-Za-z_]|String\.fromEnvironment|dotenv|process\.env|Deno\.env|=[[:space:]]*"env\([A-Za-z0-9_]+\)"[[:space:]]*(#.*)?$|TODO|FIXME|\*\*\*|\.\.\.'

# Combine Tier 1 into one alternation. Running 17 greps per file spawns
# thousands of processes and takes minutes on Windows; one bulk grep over the
# whole file list takes well under a second.
COMBINED=''
while IFS='~' read -r pat _label; do
  [ -z "$pat" ] && continue
  if [ -z "$COMBINED" ]; then COMBINED="($pat)"; else COMBINED="$COMBINED|($pat)"; fi
done < <(printf '%s\n' "$TIER1")

# Only called for actual hits, so the per-pattern loop costs nothing in the
# common case of a clean tree.
label_for() {
  local match="$1" pat label
  while IFS='~' read -r pat label; do
    [ -z "$pat" ] && continue
    if printf '%s' "$match" | grep -qE -e "^($pat)$" 2>/dev/null; then
      printf '%s' "$label"; return 0
    fi
  done < <(printf '%s\n' "$TIER1")
  printf 'credential-shaped string'
}

# Reads `path:line:text` records produced by a bulk grep and turns them into
# findings. $2 is a prefix to strip from displayed paths.
collect() {
  local kind="$1" strip="$2" line path ln text label redacted trimmed
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    path=${line%%:*}; line=${line#*:}
    ln=${line%%:*};   text=${line#*:}
    path=${path#"$strip"}; path=${path#./}
    is_exempt "$path" && continue
    if [ "$kind" = SECRET ]; then
      label=$(label_for "$text")
      redacted=$(printf '%s' "$text" | cut -c1-10)
      printf '%s\t%s\tSECRET\t%s (match: %s...)\n' "$path" "$ln" "$label" "$redacted" >> "$FINDINGS"
    else
      printf '%s' "$text" | grep -qE -e "$TIER2_ALLOW" && continue
      trimmed=$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-60)
      printf '%s\t%s\tASSIGN\tcredential-shaped assignment: %s\n' "$path" "$ln" "$trimmed" >> "$FINDINGS"
    fi
  done
}

# grep flags: -H always print filename (output shape must not change with file
# count), -I skip binaries, -o print only the match (Tier 1 only), -e so
# patterns starting with `-` are not parsed as options.
scan_tree() {
  local dir="$1" strip="$2"
  ( cd "$dir" && find . -type f -print0 ) > "$WORK/paths" 2>/dev/null || return 0
  [ -s "$WORK/paths" ] || return 0
  ( cd "$dir" && xargs -0 grep -HnEoI -e "$COMBINED" -- < "$WORK/paths" 2>/dev/null ) \
    | collect SECRET "$strip" || true
  ( cd "$dir" && xargs -0 grep -HnEiI -e "$TIER2_RE" -- < "$WORK/paths" 2>/dev/null ) \
    | collect ASSIGN "$strip" || true
}

# ── Collect and scan ──────────────────────────────────────────────────────
if [ "$SCAN_ALL" -eq 1 ]; then
  echo "check-secrets: scanning all tracked files..."
  git ls-files -z > "$WORK/tracked"
  while IFS= read -r -d '' path; do check_filename "$path"; done < "$WORK/tracked"

  # Encoding, in bulk. Calling check_encoding per file spawns three processes
  # each and took 95s across ~230 tracked files; this is two greps.
  #
  # `grep -LI` lists files grep considers BINARY. A UTF-16 text file lands in
  # that list, which is the whole trick — real binaries are then filtered out
  # by extension, and whatever remains is text that should not have been
  # encoded as UTF-16.
  xargs -0 grep -LI . -- < "$WORK/tracked" 2>/dev/null | while IFS= read -r path; do
    case "$path" in
      *.png|*.jpg|*.jpeg|*.gif|*.ico|*.ttf|*.otf|*.woff|*.woff2|*.jks|*.keystore|*.aab|*.apk|*.so|*.zip|*.pdf|*.webp|*.mp3|*.wav|*.jar|*.bin)
        continue ;;
    esac
    # An EMPTY file also has "no text match", and an empty file obviously has
    # no NUL bytes. Without this, `docs/.project_structure_ignore` (0 bytes)
    # was reported as UTF-16 corruption — a false positive that would have
    # taught the next person to ignore this check.
    [ -s "$path" ] || continue
    printf '%s\t-\tENCODING\tNUL bytes present: UTF-16 written where UTF-8 was expected\n' \
      "$path" >> "$FINDINGS"
  done

  xargs -0 grep -lI $'\xc3\xa2\xe2\x82\xac' -- < "$WORK/tracked" 2>/dev/null |
    while IFS= read -r path; do
      printf '%s\t-\tENCODING\tmojibake: UTF-8 decoded as ANSI and re-encoded (use Get-Content -Encoding utf8)\n' \
        "$path" >> "$FINDINGS"
    done
  xargs -0 grep -HnEoI -e "$COMBINED" -- < "$WORK/tracked" 2>/dev/null \
    | collect SECRET '' || true
  xargs -0 grep -HnEiI -e "$TIER2_RE" -- < "$WORK/tracked" 2>/dev/null \
    | collect ASSIGN '' || true
else
  # Staged additions/modifications. Scan the STAGED blob, not the worktree
  # file, so `git add` followed by a later edit cannot sneak a secret past.
  # Blobs are materialised under $WORK/staged mirroring their real paths so
  # the same bulk scanner and the same reported paths apply.
  mkdir -p "$WORK/staged"
  while IFS= read -r -d '' path; do
    check_filename "$path"
    mkdir -p "$WORK/staged/$(dirname "$path")" 2>/dev/null || true
    if git show ":$path" > "$WORK/staged/$path" 2>/dev/null; then
      check_encoding "$path" "$WORK/staged/$path"
    fi
  done < <(git diff --cached --name-only --diff-filter=ACMR -z)
  scan_tree "$WORK/staged" ''
fi

# ── Report ────────────────────────────────────────────────────────────────
if [ ! -s "$FINDINGS" ]; then
  printf '%s✓%s check-secrets: no credentials or encoding damage detected.\n' "$GREEN" "$OFF"
  exit 0
fi

count=$(wc -l < "$FINDINGS" | tr -d ' ')
printf '\n%s%s✗ check-secrets: %s problem(s) found.%s\n\n' "$RED" "$BOLD" "$count" "$OFF"
while IFS="$TAB" read -r path ln kind detail; do
  if [ "$ln" = "-" ]; then
    printf '  %s%s%s\n      %s: %s\n' "$RED" "$path" "$OFF" "$kind" "$detail"
  else
    printf '  %s%s:%s%s\n      %s: %s\n' "$RED" "$path" "$ln" "$OFF" "$kind" "$detail"
  fi
done < "$FINDINGS"

echo
if grep -q "${TAB}ENCODING${TAB}" "$FINDINGS"; then
  cat <<'EOF'
ENCODING findings: the file was written as UTF-16, or read as ANSI and
re-encoded. Both are invisible in most editors and both have already cost
this repository real damage -- a UTF-16 .gitignore rule that silently matched
nothing let a live token stay tracked for eleven months.

  On Windows, write UTF-8 explicitly:
    Add-Content file 'text' -Encoding utf8
    Get-Content file -Encoding utf8
EOF
fi
if grep -qE "${TAB}(SECRET|ASSIGN|FILENAME)${TAB}" "$FINDINGS"; then
  cat <<'EOF'
CREDENTIAL findings: do not "fix" this by deleting the line and committing --
if the secret was ever pushed it is already public, and deleting it changes
nothing. See SECURITY-REMEDIATION.md.

  1. Revoke and regenerate the credential at its provider, now.
  2. Move it out of source: --dart-define for build-time client values,
     Supabase Function secrets for anything the server holds.
  3. Re-stage and commit.
EOF
fi
cat <<'EOF'

This commit is blocked. False positive? Say why in the commit message and
re-run with:  git commit --no-verify
EOF
exit 1
