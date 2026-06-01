#!/usr/bin/env bash
# Section 2: Dockerfile build
set +e
ROOT="/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web"
LOG="$ROOT/log/test_run"
mkdir -p "$LOG"

build_one() {
    local name="$1" dir="$2"
    local start end elapsed
    echo "===== BUILD: aisum-test/$name ====="
    start=$(date +%s)
    docker build -t "aisum-test/$name" "$ROOT/docker/$dir/" > "$LOG/build_${name}.log" 2>&1
    local ec=$?
    end=$(date +%s)
    elapsed=$((end - start))
    if [ $ec -eq 0 ]; then
        echo "  PASS  ($elapsed s)"
        tail -3 "$LOG/build_${name}.log"
    else
        echo "  FAIL  exit=$ec  ($elapsed s)"
        echo "--- last 40 lines of log ---"
        tail -40 "$LOG/build_${name}.log"
    fi
    echo "$name $ec $elapsed" >> "$LOG/build_summary.txt"
}

: > "$LOG/build_summary.txt"
build_one nginx    nginx
build_one gunicorn gunicorn
build_one uwsgi    uwsgi
build_one php-fpm  php-fpm

echo ""
echo "===== build summary ====="
cat "$LOG/build_summary.txt"
echo ""
docker images | grep -E "aisum-test/" || echo "no aisum-test images"
