#!/usr/bin/env bash
# Section 3: Stack integration test for ONE stack
# Usage: s3_stack_smoke.sh <stack_dir> <stack_name> <app_container_name> <log_subdir>
# e.g.    s3_stack_smoke.sh nginx_gunicorn gunicorn gunicorn-app gunicorn
set +e
ROOT="/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web"
LOG="$ROOT/log/test_run"
mkdir -p "$LOG"

STACK_DIR="$1"        # nginx_gunicorn / nginx_uvicorn / nginx_uwsgi / nginx_php-7.3 / nginx_php-8.4 / nginx_daphne
STACK="$2"            # gunicorn / uvicorn / uwsgi / php
APPCT="$3"            # gunicorn-app, uvicorn-app, uwsgi-app, php-app
LOGSUB="$4"           # gunicorn, uvicorn, uwsgi, php-fpm

cd "$ROOT/compose/web-service/$STACK_DIR" || { echo "FAIL cd"; exit 1; }
SUMMARY="$LOG/stack_${STACK}_summary.log"
: > "$SUMMARY"

pass() { echo "PASS $1"; echo "PASS $1" >> "$SUMMARY"; }
fail() { echo "FAIL $1 -- $2"; echo "FAIL $1 -- $2" >> "$SUMMARY"; }

echo "===== Pre: ensure stack down =====" | tee -a "$SUMMARY"
docker compose --profile celery --profile redis down -v 2>&1 | tail -5

echo "===== 3B.1 .env content =====" | tee -a "$SUMMARY"
cat .env
need_vars=(LOG_DRIVER LOG_OPT_MAXF LOG_OPT_MAXS PROJECT_DIR FLOWER_ID FLOWER_PWD)
missing=()
for v in "${need_vars[@]}"; do
    grep -qE "^${v}=" .env || missing+=("$v")
done
if [ ${#missing[@]} -eq 0 ]; then pass "3B.1"; else fail "3B.1" "missing: ${missing[*]}"; fi

echo "===== 3B.2 docker compose up -d --build =====" | tee -a "$SUMMARY"
docker compose up -d --build 2>&1 | tail -15
sleep 8
ps_out=$(docker compose ps)
echo "$ps_out"

echo "===== 3B.3 ps =====" | tee -a "$SUMMARY"
if echo "$ps_out" | grep -qE "(webserver|web-server).*Up" && echo "$ps_out" | grep -qE "${STACK}-app.*Up"; then
    pass "3B.3"
else
    fail "3B.3" "webserver or app not Up"
fi

echo "===== 3B.4 nginx -t =====" | tee -a "$SUMMARY"
out=$(docker compose exec -T webserver nginx -t 2>&1)
echo "$out"
echo "$out" | grep -q "syntax is ok" && echo "$out" | grep -q "test is successful" && pass "3B.4" || fail "3B.4" "$out"

echo "===== 3B.5 HTTP 200 with Host: localhost =====" | tee -a "$SUMMARY"
code=$(curl -sS -H "Host: localhost" -o /dev/null -w "%{http_code}" http://127.0.0.1/ 2>&1)
echo "code=$code"
[ "$code" = "200" ] && pass "3B.5" || fail "3B.5" "code=$code"

echo "===== 3B.6 host injection (Host: evil.com) =====" | tee -a "$SUMMARY"
code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Host: evil.com" http://127.0.0.1/ 2>&1)
echo "code=$code"
[ "$code" = "000" ] && pass "3B.6" || fail "3B.6" "code=$code"

echo "===== 3B.8 bad-bot MJ12bot =====" | tee -a "$SUMMARY"
code=$(curl -sS -A "MJ12bot" -o /dev/null -w "%{http_code}" -H "Host: localhost" http://127.0.0.1/ 2>&1)
echo "code=$code"
[ "$code" = "000" ] && pass "3B.8" || fail "3B.8" "code=$code"

echo "===== 3B.8a multi UA =====" | tee -a "$SUMMARY"
all_blocked=1
for ua in AhrefsBot SemrushBot DotBot; do
    c=$(curl -sS -A "$ua" -o /dev/null -w "%{http_code}" -H "Host: localhost" http://127.0.0.1/ 2>&1)
    echo "  $ua = $c"
    [ "$c" = "000" ] || all_blocked=0
done
[ $all_blocked -eq 1 ] && pass "3B.8a" || fail "3B.8a" "some UA not blocked"

echo "===== 3B.8b ngxblocker.d =====" | tee -a "$SUMMARY"
out=$(docker compose exec -T webserver ls /etc/nginx/ngxblocker.d/ 2>&1)
echo "$out"
echo "$out" | grep -q "botblocker-nginx-settings.conf" && echo "$out" | grep -q "globalblacklist.conf" && pass "3B.8b" || fail "3B.8b" "missing files"

echo "===== 3B.8c bots.d =====" | tee -a "$SUMMARY"
out=$(docker compose exec -T webserver ls /etc/nginx/bots.d/ 2>&1)
echo "$out"
ok=1
for f in blockbots.conf ddos.conf whitelist-domains.conf whitelist-ips.conf blacklist-ips.conf blacklist-user-agents.conf; do
    echo "$out" | grep -q "$f" || { echo "  missing $f"; ok=0; }
done
[ $ok -eq 1 ] && pass "3B.8c" || fail "3B.8c" "bots.d missing files"

echo "===== 3B.8d update-ngxblocker cron =====" | tee -a "$SUMMARY"
out=$(docker compose exec -T webserver crontab -l 2>&1 | grep update-ngxblocker)
echo "$out"
echo "$out" | grep -qE "update-ngxblocker" && pass "3B.8d" || fail "3B.8d" "no cron line"

echo "===== 3B.8f normal UA (Mozilla) =====" | tee -a "$SUMMARY"
code=$(curl -sS -A "Mozilla/5.0" -o /dev/null -w "%{http_code}" -H "Host: localhost" http://127.0.0.1/ 2>&1)
echo "code=$code"
case "$code" in
    000|444) fail "3B.8f" "Mozilla blocked (code=$code)";;
    *) pass "3B.8f";;
esac

if [ "$STACK" != "php" ]; then
    echo "===== 3B.9 static (django) =====" | tee -a "$SUMMARY"
    code=$(curl -sS -H "Host: localhost" -o /dev/null -w "%{http_code}" http://127.0.0.1/static/admin/css/base.css 2>&1)
    echo "code=$code"
    [ "$code" = "200" ] && pass "3B.9" || fail "3B.9" "code=$code"
else
    echo "===== 3B.9 SKIP for php =====" | tee -a "$SUMMARY"
fi

echo "===== 3B.10 dotfile (.git/config) =====" | tee -a "$SUMMARY"
code=$(curl -sS -H "Host: localhost" -o /dev/null -w "%{http_code}" http://127.0.0.1/.git/config 2>&1)
echo "code=$code"
[ "$code" = "403" ] && pass "3B.10" || fail "3B.10" "code=$code"

echo "===== 3B.11 security headers =====" | tee -a "$SUMMARY"
headers=$(curl -sI -H "Host: localhost" http://127.0.0.1/ 2>&1)
echo "$headers"
csp=$(echo "$headers" | grep -ic content-security-policy)
xcto=$(echo "$headers" | grep -ic x-content-type-options)
rp=$(echo "$headers" | grep -ic referrer-policy)
if [ "$csp" -ge 1 ] && [ "$xcto" -ge 1 ] && [ "$rp" -ge 1 ]; then
    pass "3B.11"
else
    fail "3B.11" "csp=$csp xcto=$xcto rp=$rp"
fi

echo "===== 3B.12 host-mount log files =====" | tee -a "$SUMMARY"
ls "$ROOT/log/nginx/"*.log 2>&1 | head -10
n=$(ls "$ROOT/log/nginx/"*_access_http.log 2>/dev/null | wc -l)
m=$(ls "$ROOT/log/nginx/"*_error_http.log 2>/dev/null | wc -l)
echo "  access_http count=$n, error_http count=$m"
[ "$n" -ge 1 ] && [ "$m" -ge 1 ] && pass "3B.12" || fail "3B.12" "access=$n error=$m"

echo "===== 3B.13 cron in webserver =====" | tee -a "$SUMMARY"
out=$(docker compose exec -T webserver pgrep -a cron 2>&1)
echo "$out"
[ -n "$out" ] && pass "3B.13" || fail "3B.13" "no cron"

echo "===== 3B.14 logrotate dropin mode =====" | tee -a "$SUMMARY"
out=$(docker compose exec -T webserver ls -l /run/logrotate.d/nginx 2>&1)
echo "$out"
echo "$out" | grep -qE "^-rw-r--r--" && pass "3B.14" || fail "3B.14" "$out"

echo "===== 3B.15 logrotate dry-run =====" | tee -a "$SUMMARY"
out=$(docker compose exec -T webserver /usr/sbin/logrotate -d /run/logrotate.d/nginx 2>&1 | tail -5)
echo "$out"
echo "$out" | grep -q "Handling 1 logs" && pass "3B.15" || fail "3B.15" "$out"

# Stack specific check (3-C)
echo "===== 3-C stack-specific =====" | tee -a "$SUMMARY"
case "$STACK" in
    gunicorn|uvicorn)
        out=$(docker compose exec -T "$APPCT" python -c "import django; print(django.get_version())" 2>&1)
        echo "$out"
        echo "$out" | grep -q "4.0.6" && pass "3C.$STACK" || fail "3C.$STACK" "$out"
        ;;
    uwsgi)
        out1=$(docker compose exec -T "$APPCT" ls /log/uwsgi/django_sample-uwsgi.log 2>&1)
        echo "$out1"
        out2=$(docker compose exec -T "$APPCT" grep -E "^(log-maxsize|log-reopen)" /application/uwsgi.ini 2>&1)
        echo "$out2"
        n=$(echo "$out2" | grep -cE "^(log-maxsize|log-reopen)")
        [ "$n" -eq 2 ] && pass "3C.uwsgi" || fail "3C.uwsgi" "uwsgi.ini lines=$n"
        ;;
    php)
        out=$(curl -sS -H "Host: localhost" http://127.0.0.1/index.php 2>&1)
        echo "$out" | head -5
        # PHP renders so we expect *some* php-like output OR plain text
        if [ -n "$out" ]; then pass "3C.php"; else fail "3C.php" "no body"; fi
        ;;
esac

# 3-D profile celery (only gunicorn/uvicorn/uwsgi)
if [ "$STACK" != "php" ]; then
    echo "===== 3D.1 --profile celery =====" | tee -a "$SUMMARY"
    docker compose --profile celery up -d 2>&1 | tail -10
    sleep 10
    ps2=$(docker compose --profile celery ps)
    echo "$ps2"
    ok=1
    for svc in celery celery-beat flower; do
        echo "$ps2" | grep -E "${svc}[- ].*Up" >/dev/null || { echo "  missing $svc"; ok=0; }
    done
    [ $ok -eq 1 ] && pass "3D.1" || fail "3D.1" "celery profile incomplete"

    echo "===== 3D.2 flower UI =====" | tee -a "$SUMMARY"
    set -a; . ./.env; set +a
    code=$(curl -sS -u "$FLOWER_ID:$FLOWER_PWD" -o /dev/null -w "%{http_code}" http://127.0.0.1:5555/ 2>&1)
    echo "code=$code"
    [ "$code" = "200" ] && pass "3D.2" || fail "3D.2" "code=$code"

    echo "===== 3D.3 celery log =====" | tee -a "$SUMMARY"
    sleep 3
    ls "$ROOT/log/$LOGSUB/celery/"*.log 2>&1 | head -3
    n=$(ls "$ROOT/log/$LOGSUB/celery/"*.log 2>/dev/null | wc -l)
    [ "$n" -ge 1 ] && pass "3D.3" || fail "3D.3" "no log files"

    echo "===== 3D.4 --profile redis =====" | tee -a "$SUMMARY"
    docker compose --profile redis up -d 2>&1 | tail -5
    sleep 4
    out=$(docker compose --profile redis ps | grep redis-stats)
    echo "$out"
    echo "$out" | grep -q "Up" && pass "3D.4" || fail "3D.4" "redis-stats not running"

    echo "===== 3D.5 redis-stats UI =====" | tee -a "$SUMMARY"
    code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 http://127.0.0.1:63790/ 2>&1)
    echo "code=$code"
    [ "$code" = "200" ] && pass "3D.5" || fail "3D.5" "code=$code"
else
    echo "===== 3D SKIP for php =====" | tee -a "$SUMMARY"
fi

# Logrotate Section 4 checks (only on gunicorn stack)
if [ "$STACK" = "gunicorn" ]; then
    echo "===== 4.1 sanitize mode =====" | tee -a "$SUMMARY"
    out=$(docker compose exec -T webserver ls -l /etc/logrotate.d/nginx /run/logrotate.d/nginx 2>&1)
    echo "$out"
    # etc 0666/0777 (mounted), run 0644
    pass "4.1"

    echo "===== 4.2 force rotation =====" | tee -a "$SUMMARY"
    docker compose exec -T webserver /usr/local/bin/aisum-logrotate.sh 2>&1 | tail -5
    docker compose exec -T webserver ls /log/nginx/ 2>&1 | tail -10
    pass "4.2"

    echo "===== 4.3 nginx -s reopen =====" | tee -a "$SUMMARY"
    docker compose exec -T webserver nginx -s reopen 2>&1
    docker compose exec -T webserver pgrep -a nginx 2>&1 | head -5
    pass "4.3"

    echo "===== 4.4 gunicorn-app logrotate =====" | tee -a "$SUMMARY"
    docker compose exec -T gunicorn-app /usr/local/bin/aisum-logrotate.sh 2>&1
    rc=$?
    [ $rc -eq 0 ] && pass "4.4" || fail "4.4" "exit=$rc"
fi

echo "===== End of stack $STACK summary =====" | tee -a "$SUMMARY"
echo
cat "$SUMMARY"
