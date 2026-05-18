#!/usr/bin/env bash
# devspoon-web 통합 테스트 시작 가능 여부 자동 점검
# Usage:  bash script/test/preflight.sh
# Exit:   0 = PASS (테스트 시작 가능), 1 = FAIL (선결 결격)
#
# 본 스크립트는 read-only — 어떤 상태도 변경하지 않는다.

set -u

errs=0
warns=0
ROOT=${ROOT:-$(pwd)}

# ----- helper -----
check() {
    local desc=$1 cmd=$2
    if eval "$cmd" >/dev/null 2>&1; then
        printf "  [OK]    %s\n" "$desc"
    else
        printf "  [MISS]  %s\n" "$desc"
        errs=$((errs + 1))
    fi
}
warn() {
    local desc=$1 cmd=$2
    if eval "$cmd" >/dev/null 2>&1; then
        printf "  [OK]    %s\n" "$desc"
    else
        printf "  [WARN]  %s\n" "$desc"
        warns=$((warns + 1))
    fi
}

# ----- (1) 도구 -----
echo "[1] Required tools"
check "docker (>=24)"          "docker --version"
check "docker compose (v2)"    "docker compose version"
check "jq"                     "jq --version"
check "curl"                   "curl --version"
check "openssl"                "openssl version"
warn  "wrk (load test, optional)" "wrk --version 2>&1 | head -1"

# ----- (2) 리포 파일 -----
echo "[2] Repository files"
check ".env (nginx_gunicorn)"  "test -f $ROOT/compose/web_service/nginx_gunicorn/.env"
check ".env (nginx_uvicorn)"   "test -f $ROOT/compose/web_service/nginx_uvicorn/.env"
check ".env (nginx_daphne)"    "test -f $ROOT/compose/web_service/nginx_daphne/.env"
check ".env (nginx_uwsgi)"     "test -f $ROOT/compose/web_service/nginx_uwsgi/.env"
check ".env (nginx_php-7.3)"   "test -f $ROOT/compose/web_service/nginx_php-7.3/.env"
check ".env (nginx_php-8.4)"   "test -f $ROOT/compose/web_service/nginx_php-8.4/.env"
check "Dockerfile (gunicorn)"  "test -f $ROOT/docker/gunicorn/Dockerfile"
check "Dockerfile (uwsgi)"     "test -f $ROOT/docker/uwsgi/Dockerfile"
check "Dockerfile (nginx)"     "test -f $ROOT/docker/nginx/Dockerfile"
check "Dockerfile (php-fpm 7.3)" "test -f $ROOT/docker/php-fpm/Dockerfile-7.3"
check "Dockerfile (php-fpm 8.4)" "test -f $ROOT/docker/php-fpm/Dockerfile-8.4"
check "entrypoint-with-cron (gunicorn)" "test -f $ROOT/docker/gunicorn/entrypoint-with-cron.sh"
check "entrypoint-with-cron (uwsgi)"    "test -f $ROOT/docker/uwsgi/entrypoint-with-cron.sh"
check "pyproject.toml"         "test -f $ROOT/www/django_sample/pyproject.toml"
check "requirements.txt"       "test -f $ROOT/www/django_sample/requirements.txt"
check "letsencrypt.sh"         "test -f $ROOT/script/letsencrypt.sh"

# ----- (3) 회귀 / 디자인 정합 (read-only grep) -----
echo "[3] Design invariants"
check "logrotate folder (not 'loglotate')" \
      "test -d $ROOT/script/logrotate && ! test -d $ROOT/script/loglotate"
check "log/ has .gitkeep × 11" \
      "[ \$(find $ROOT/log/ -name .gitkeep 2>/dev/null | wc -l) -eq 11 ]"
check "pyproject.toml is PEP 621 (no [tool.poetry])" \
      "grep -q '^\[project\]' $ROOT/www/django_sample/pyproject.toml && \
       ! grep -q '^\[tool.poetry\]' $ROOT/www/django_sample/pyproject.toml"
check "Dockerfile UV_PROJECT_ENVIRONMENT=/usr/local (gunicorn)" \
      "grep -q 'UV_PROJECT_ENVIRONMENT=/usr/local' $ROOT/docker/gunicorn/Dockerfile"
check "Dockerfile UV_PROJECT_ENVIRONMENT=/usr/local (uwsgi)" \
      "grep -q 'UV_PROJECT_ENVIRONMENT=/usr/local' $ROOT/docker/uwsgi/Dockerfile"
check "Dockerfile FROM ubuntu:24.04 (gunicorn)" \
      "head -1 $ROOT/docker/gunicorn/Dockerfile | grep -q '^FROM ubuntu:24.04'"
check "Dockerfile FROM ubuntu:24.04 (uwsgi)" \
      "head -1 $ROOT/docker/uwsgi/Dockerfile | grep -q '^FROM ubuntu:24.04'"
check "Dockerfile FROM nginx:1.27 (nginx)" \
      "head -1 $ROOT/docker/nginx/Dockerfile | grep -qE '^FROM nginx:1\.27'"
check "compose: no poetry references" \
      "! grep -rq 'poetry install\|poetry config' $ROOT/compose/"
check "compose: no 'uv run' in active commands" \
      "! grep -rqE '^\s*command:.*uv run' $ROOT/compose/"
check "compose: no 'service nginx restart' (regression)" \
      "! grep -rnE 'service[[:space:]]+nginx[[:space:]]+(restart|reload)' $ROOT/docker/ $ROOT/script/ $ROOT/compose/ \
         --exclude-dir=test 2>/dev/null \
         | grep -vE ':[0-9]+:[[:space:]]*#' \
         | grep -q ."
check "uwsgi.ini py-autoreload=0" \
      "grep -qE '^py-autoreload\s*=\s*0' $ROOT/config/app-server/uwsgi/uwsgi.ini"

# ----- (4) 호스트 환경 (정보성, FAIL 아님) -----
echo "[4] Host environment (informational)"
warn  "WSL2 detected"                "grep -qi microsoft /proc/version"
warn  "Disk free >= 20GB at \$PWD"   "[ \$(df -BG --output=avail . | tail -1 | tr -dc 0-9) -ge 20 ]"
warn  "net.core.somaxconn >= 4096"   "[ \$(sysctl -n net.core.somaxconn 2>/dev/null || echo 0) -ge 4096 ]"

# ----- 결과 -----
echo ""
if [ $errs -eq 0 ]; then
    printf "PREFLIGHT PASS — ready to run tests (warnings: %d)\n" "$warns"
    exit 0
fi
printf "PREFLIGHT FAIL — %d issue(s), warnings: %d. Fix before running tests.\n" "$errs" "$warns"
exit 1
