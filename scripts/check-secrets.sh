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
TIER2_ALLOW='your_|_here|YOUR_|placeholder|example|EXAMPLE|changeme|CHANGEME|xxxx|XXXX|<[^>]*>|\$\{|\$[A-Za-z_]|String\.fromEnvironment|dotenv|process\.env|Deno\.env|TODO|FIXME|\*\*\*|\.\.\.'

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
    git show ":$path" > "$WORK/staged/$path" 2>/dev/null || true
  done < <(git diff --cached --name-only --diff-filter=ACMR -z)
  scan_tree "$WORK/staged" ''
fi

# ── Report ────────────────────────────────────────────────────────────────
if [ ! -s "$FINDINGS" ]; then
  printf '%s✓%s check-secrets: no credentials detected.\n' "$GREEN" "$OFF"
  exit 0
fi

count=$(wc -l < "$FINDINGS" | tr -d ' ')
printf '\n%s%s✗ check-secrets: %s potential credential(s) found.%s\n\n' "$RED" "$BOLD" "$count" "$OFF"
while IFS="$TAB" read -r path ln kind detail; do
  if [ "$ln" = "-" ]; then
    printf '  %s%s%s\n      %s: %s\n' "$RED" "$path" "$OFF" "$kind" "$detail"
  else
    printf '  %s%s:%s%s\n      %s: %s\n' "$RED" "$path" "$ln" "$OFF" "$kind" "$detail"
  fi
done < "$FINDINGS"

cat <<'EOF'

This commit is blocked. Do not "fix" it by deleting the line and committing --
if the secret was ever pushed it is already public, and deleting it changes
nothing. See SECURITY-REMEDIATION.md.

  1. Revoke and regenerate the credential at its provider, now.
  2. Move it out of source: --dart-define for build-time client values,
     Supabase Function secrets for anything the server holds.
  3. Re-stage and commit.

False positive? Say why in the commit message and re-run with:
  git commit --no-verify
EOF
exit 1
