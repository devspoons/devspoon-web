#!/usr/bin/env bash
# Section 2: Dockerfile build
set +e
ROOT="/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web"
LOG="$ROOT/log/test_run"
mkdir -p "$LOG"

# $1=tag suffix, $2=context dir under docker/, $3=optional Dockerfile name (default: Dockerfile)
build_one() {
    local name="$1" dir="$2" dockerfile="${3:-Dockerfile}"
    local start end elapsed
    echo "===== BUILD: aisum-test/$name ====="
    start=$(date +%s)
    docker build -f "$ROOT/docker/$dir/$dockerfile" -t "aisum-test/$name" "$ROOT/docker/$dir/" > "$LOG/build_${name}.log" 2>&1
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
build_one nginx        nginx
build_one gunicorn     gunicorn
build_one uwsgi        uwsgi
# php-fpm context has no plain `Dockerfile` — two variants must be selected explicitly.
build_one php-fpm-7.3  php-fpm  Dockerfile-7.3
build_one php-fpm-8.4  php-fpm  Dockerfile-8.4

echo ""
echo "===== build summary ====="
cat "$LOG/build_summary.txt"
echo ""
docker images | grep -E "aisum-test/" || echo "no aisum-test images"
