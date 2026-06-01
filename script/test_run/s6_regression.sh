#!/usr/bin/env bash
# Section 6: static regression
set +e
ROOT="/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web"
cd "$ROOT" || exit 1

run() {
    local label="$1"; shift
    echo "===== $label ====="
    "$@"
    echo "  exit=$?"
    echo
}

echo "===== 6.1 host injection regex bug ====="
n=$(grep -rE 'domain\\\.\\\(com' config/web-server/ 2>/dev/null | wc -l)
echo "matches=$n (expected 0)"
echo

echo "===== 6.2 CSP frame-ancestors 'self' uniform ====="
# expected: no rows that are NOT 'self'
out=$(grep -rE "frame-ancestors '?self'?[^;]*;" config/web-server/ 2>/dev/null | grep -v "'self';" | grep -v "'self' ")
if [ -z "$out" ]; then
    echo "PASS — all frame-ancestors are 'self;'"
else
    echo "FAIL — non-'self' rows:"
    echo "$out"
fi
echo

echo "===== 6.3 log filename pattern (legacy _(http|https)_(access|error).log) ====="
n=$(grep -rE "_(http|https)_(access|error)\.log" config/web-server/ 2>/dev/null | wc -l)
echo "matches=$n (expected 0)"
echo

echo "===== 6.4 LF line endings (no CRLF) ====="
n=$(find . -type f -not -path './.git/*' -not -path './.claude/*' -not -path './log/*' -not -path './www/django_sample/.venv/*' 2>/dev/null | xargs file 2>/dev/null | grep -i CRLF | wc -l)
echo "CRLF files=$n (expected 0)"
echo "  (first 10 if any):"
find . -type f -not -path './.git/*' -not -path './.claude/*' -not -path './log/*' -not -path './www/django_sample/.venv/*' 2>/dev/null | xargs file 2>/dev/null | grep -i CRLF | head -10
echo

echo "===== 6.5 unmatched-Host catch-all = default.conf (no host-injection if in samples) ====="
# 정책: sample / generated conf 에는 `if ($host !~)` 가 있어선 안 된다.
# 알 수 없는 Host/SNI 차단은 default.conf 의 default_server (return 444 / ssl_reject_handshake) 가 단일 책임으로 담당.
n=$(grep -rnE 'if[[:space:]]*\([[:space:]]*\$host[[:space:]]*!~' config/web-server/ 2>/dev/null | wc -l)
echo "host-injection if in samples=$n (expected 0)"
grep -nE 'default_server' config/web-server/nginx/gunicorn/conf.d/default.conf | head -3
echo

echo "===== 6.6 uwsgi log-maxsize / log-reopen ====="
grep -nE '^(log-maxsize|log-reopen)' config/app-server/uwsgi/uwsgi.ini
echo

echo "===== 6.7 django_sample uv-only (no [tool.poetry]) ====="
n=$(grep -E '\[tool\.poetry\]' www/django_sample/pyproject.toml | wc -l)
echo "matches=$n (expected 0)"
echo

echo "===== 6.8 django_sample Python 3.14 ====="
cat www/django_sample/.python-version
echo

echo "===== 6.9 django_sample legacy-cgi shim ====="
grep legacy-cgi www/django_sample/pyproject.toml
echo
