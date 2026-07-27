#!/usr/bin/env bash
#
# Tests for check-secrets.sh. Run:  bash scripts/check-secrets.test.sh
#
# Two things are asserted, and the second matters as much as the first:
#   MUST CATCH    — every credential shape this repo has actually leaked.
#   MUST NOT CATCH— the identifiers that made a naive `grep -i password`
#                   useless here. A noisy hook gets disabled, so false
#                   positives are treated as test failures, not annoyances.
#
# The scanner reads staged blobs, so each case is exercised in a scratch repo
# with the content actually staged — the same path a real commit takes.

set -eu

SCANNER="$(cd "$(dirname "$0")" && pwd)/check-secrets.sh"
PASS=0
FAIL=0

run_case() {
  local name="$1" expect="$2" filename="$3" content="$4"
  local tmp rc out
  tmp=$(mktemp -d)
  (
    cd "$tmp"
    git init -q .
    git config user.email t@t.t
    git config user.name t
    mkdir -p "$(dirname "$filename")" 2>/dev/null || true
    printf '%s\n' "$content" > "$filename"
    git add -A -f "$filename" 2>/dev/null
  )
  set +e
  out=$(cd "$tmp" && NO_COLOR=1 bash "$SCANNER" 2>&1)
  rc=$?
  set -e
  rm -rf "$tmp"

  if [ "$expect" = "catch" ] && [ "$rc" -ne 0 ]; then
    printf '  ok    CATCH     %s\n' "$name"; PASS=$((PASS+1))
  elif [ "$expect" = "pass" ] && [ "$rc" -eq 0 ]; then
    printf '  ok    ALLOW     %s\n' "$name"; PASS=$((PASS+1))
  else
    printf '  FAIL  expected %s, got rc=%s :: %s\n' "$expect" "$rc" "$name"
    printf '%s\n' "$out" | sed 's/^/          /'
    FAIL=$((FAIL+1))
  fi
}

echo "== MUST CATCH: credential shapes =="

# Every fixture below is assembled at runtime from a prefix and a body, so that
# no line in this file is itself a complete credential-shaped string.
#
# This is not decoration. A test file full of realistic-looking keys trips
# GitHub secret scanning, trips any auditor who greps the repo, and — worst —
# trains the reader to see credential-shaped strings in this codebase as
# normal. The fixtures below are all fake, but nothing that *looks* like a key
# should survive a grep of this repository, including in tests.
sec() { printf '%s%s' "$1" "$2"; }

run_case "Google API key (the leaked gemini_service.dart key shape)" catch lib/s.dart \
  "final k = '$(sec 'AIza' 'SyAss8fSmad3Q60ynhwZPUnfKgsSuMZMtJY')';"
run_case "Hugging Face token (image_generation_service.dart shape)" catch lib/s.dart \
  "const t = '$(sec 'hf' '_hVyKjpFtXfqKVhXSMbQnKVLSjcDDdcDcbv')';"
run_case "Hugging Face token (.env shape)" catch config.txt \
  "HUGGING_FACE_TOKEN=$(sec 'hf' '_VUSRbAYMjTkoboqgiDumTUYpUutAytalqu')"
run_case "OpenAI secret key" catch lib/s.dart \
  "const k = '$(sec 'sk' '-abcdefghij0123456789ABCDEFGH')';"
run_case "Anthropic API key" catch lib/s.dart \
  "const k = '$(sec 'sk-ant' '-abcdefghij0123456789ABCD')';"
run_case "GitHub PAT" catch ci.yml \
  "token: $(sec 'ghp' '_abcdefghij0123456789ABCDEFGHIJKLMNOP')"
run_case "AWS access key id" catch deploy.sh \
  "AWS_ACCESS_KEY_ID=$(sec 'AKIA' 'IOSFODNN7EXAMPLZ')"
run_case "private key block" catch id.txt \
  "$(sec '-----BEGIN ' 'RSA PRIVATE KEY-----')"
run_case "Cloudinary credentials URL" catch s.dart \
  "url = '$(sec 'cloudinary' '://123456789:abcDEF_ghi')'"
run_case "Postgres URL with inline password" catch s.dart \
  "db = '$(sec 'postgres' '://user:hunter2pass@host/db')'"
run_case "hardcoded bearer token" catch s.dart \
  "'Authorization': '$(sec 'Bearer' ' abcdefghijklmnopqrstuvwxyz0123')'"
run_case "Slack token" catch s.dart \
  "const t = '$(sec 'xoxb' '-1234567890-abcdefghij')'"

echo
echo "== MUST CATCH: credential-shaped assignments =="
run_case "apiKey = literal"       catch s.dart \
  "static const apiKey = '$(sec 'a8f3k29' 'dmMzQ81xLp')';"
run_case "secret: literal (yaml)" catch conf.yaml \
  "client_secret: '$(sec 'GOCSPX' '-aB3dEf9hIjKlMnOp')'"
run_case "password = literal"     catch s.dart \
  "final password = '$(sec 'Tr0ub4' 'dor&3xyz')';"

echo
echo "== MUST CATCH: filenames =="
run_case ".env file"            catch .env "SOMETHING=1"
run_case "keystore"             catch upload.jks "binary-ish"
run_case "google-services.json" catch android/app/google-services.json '{"a":1}'
run_case "service account json" catch play-service-account.json '{"type":"service_account"}'

echo
echo "== MUST NOT CATCH: real code from this repo =="
run_case "passwordController identifier" pass lib/c.dart \
  "late final TextEditingController _passwordController; bool _obscurePassword = true;"
run_case "passwordHint constant"         pass lib/k.dart \
  "static const String passwordHint = 'Create a strong password';"
run_case "validatePassword method"       pass lib/v.dart \
  "static String? validatePasswordComplex(String? value) { return null; }"
run_case "password map key"              pass lib/v.dart \
  "errors['password'] = passwordError; if (lowercasePassword.contains(pattern)) {}"
run_case "weak-password wordlist"        pass lib/v.dart \
  "const weak = ['password', 'password123', 'letmein'];"
run_case "password error copy"           pass lib/k.dart \
  "static const passwordWeakError = 'Password must contain letters and numbers';"
run_case "String.fromEnvironment"        pass lib/s.dart \
  "static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');"
run_case "Bearer with interpolation"     pass lib/s.dart \
  "'Authorization': 'Bearer \$_hfApiKey',"
run_case "placeholder value"             pass lib/s.dart \
  "static const String _openAIApiKey = 'your_openai_api_key_here';"
run_case ".env.example template"         pass .env.example \
  "GEMINI_API_KEY="
run_case "env var reference in CI"       pass ci.yml \
  "api_key: \${{ secrets.GEMINI_API_KEY }}"
# supabase/config.toml ships three of these by default. Flagging them would
# mean every config change fights the hook, and a hook people fight is a hook
# people bypass — the failure mode CRITIQUE W0.2 describes.
run_case "supabase env() reference"      pass supabase/config.toml \
  "openai_api_key = \"env(OPENAI_API_KEY)\""
run_case "supabase env() smtp secret"    pass supabase/config.toml \
  "auth_token = \"env(SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN)\""
# The allowlist above must not become a way to smuggle a real value: Tier 1
# credential shapes are matched before it is consulted, so a literal key on a
# line that also mentions env() is still caught.
run_case "real key beside env() marker"  catch supabase/config.toml \
  "openai_api_key = \"sk-proj-Ab3dEf6hIj9lMn2pQr5tUv8xYz1aBc4dEf7hIj0lMn3pQr6t\" # env(X)"

echo
echo "== MUST CATCH: encoding damage =="
#
# Both failures this repository actually suffered, reproduced byte for byte.
# Written through Python so the test file itself stays clean UTF-8 — a test
# fixture that is corrupt on disk would trip the very check it is testing.

run_case_bytes() {
  local name="$1" expect="$2" filename="$3" pyexpr="$4"
  local tmp rc out
  tmp=$(mktemp -d)
  (
    cd "$tmp"
    git init -q .
    git config user.email t@t.t
    git config user.name t
    mkdir -p "$(dirname "$filename")" 2>/dev/null || true
    python -c "import io,sys; io.open(sys.argv[1],'wb').write($pyexpr)" "$filename"
    git add -A -f "$filename" 2>/dev/null
  )
  set +e
  out=$(cd "$tmp" && NO_COLOR=1 bash "$SCANNER" 2>&1)
  rc=$?
  set -e
  rm -rf "$tmp"

  if [ "$expect" = "catch" ] && [ "$rc" -ne 0 ]; then
    printf '  ok    CATCH     %s\n' "$name"; PASS=$((PASS+1))
  elif [ "$expect" = "pass" ] && [ "$rc" -eq 0 ]; then
    printf '  ok    ALLOW     %s\n' "$name"; PASS=$((PASS+1))
  else
    printf '  FAIL  expected %s, got rc=%s :: %s\n' "$expect" "$rc" "$name"
    printf '%s\n' "$out" | sed 's/^/          /'
    FAIL=$((FAIL+1))
  fi
}

# The Milestone 0 root cause: PowerShell wrote `.env` as UTF-16LE, git read
# `.\0e\0n\0v`, the ignore rule matched nothing, a token leaked for months.
run_case_bytes "UTF-16LE text file (the .gitignore root cause)" catch rules.txt \
  "b'build/\r\n' + '.env'.encode('utf-16-le')"

# The Milestone 1 repeat: Get-Content without -Encoding utf8 decoded UTF-8 as
# cp1252 and re-encoded, turning every em-dash into three bytes of noise.
run_case_bytes "mojibake: UTF-8 decoded as cp1252 and re-encoded" catch lib/x.dart \
  "'// a comment — with an em dash'.encode('utf-8').decode('cp1252').encode('utf-8')"

run_case_bytes "clean UTF-8 with a real em-dash is allowed" pass lib/x.dart \
  "'// a comment — with an em dash'.encode('utf-8')"

run_case_bytes "plain ASCII is allowed" pass lib/x.dart \
  "b'// plain ascii'"

echo
printf 'passed %s, failed %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
