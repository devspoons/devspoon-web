#!/usr/bin/env bash
# Section 1-B: nginx_http_conf.sh / nginx_https_conf.sh generators
set +e
ROOT="/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web"
NGX="$ROOT/config/web-server/nginx"

stacks="gunicorn uvicorn uwsgi"   # php is handled separately for -w/-a/-s

run_stack() {
    local stack="$1" webroot="$2" app="$3" sport="$4"
    echo "===== STACK: $stack ====="
    cd "$NGX/$stack" || return 1
    # 1B.1 http
    echo "--- 1B.1 ($stack) HTTP non-interactive ---"
    ./nginx_http_conf.sh -w "$webroot" -p 80 -d test.local -a "$app" -s "$sport" -n autotest_http 2>&1 | tail -5
    ls conf.d/autotest_http_${stack}_http_ng.conf 2>&1
    # 1B.2 https
    echo "--- 1B.2 ($stack) HTTPS non-interactive ---"
    ./nginx_https_conf.sh -w "$webroot" -p 80 -d test.local -a "$app" -s "$sport" -n autotest_https 2>&1 | tail -5
    ls conf.d/autotest_https_${stack}_https_ng.conf 2>&1
    # 1B.3 placeholder substitution
    echo "--- 1B.3 ($stack) placeholders left in files (should be 0) ---"
    grep -E '(domain|appname|webroot|portnumber|filename|serviceport)' conf.d/autotest_*_ng.conf 2>&1
    echo "  (grep returncode = $?)"
    # 1B.5 invalid input
    echo "--- 1B.5 ($stack) invalid input -> expect exit 2 ---"
    ./nginx_http_conf.sh -w x -p 99999 -d X -a Y -s Z 2>&1 | tail -3
    echo "  (exit code: $?)"
    # 1B.6 cleanup
    echo "--- 1B.6 ($stack) cleanup autotest_* ---"
    rm -f conf.d/autotest_*
    ls conf.d/autotest_* 2>&1 | head -3
}

for s in $stacks; do
    run_stack "$s" "django_sample" "${s}-app" "8000"
done

# php variant
run_stack "php" "php_sample" "php" "9000"
