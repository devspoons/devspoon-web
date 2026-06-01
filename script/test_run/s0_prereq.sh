#!/usr/bin/env bash
# Section 0: Prerequisite check
set +e
ROOT="/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web"
cd "$ROOT" || exit 1

echo "===== 0.1 docker version ====="
docker version 2>&1 | grep -E "(Server|Engine|Version)" | head -10

echo "===== 0.2 docker compose version ====="
docker compose version

echo "===== 0.3 port check (80/443/5555/63790) ====="
ss -lntp 2>/dev/null | grep -E ':(80|443|5555|63790)\b' || echo "(no host listener)"

echo "===== 0.3b currently running containers ====="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo "===== 0.4 uv ====="
command -v uv
uv --version

echo "===== 0.5 log directories ====="
for d in nginx gunicorn gunicorn/celery gunicorn/celerybeat uvicorn uvicorn/celery uvicorn/celerybeat uwsgi uwsgi/celery uwsgi/celerybeat php-fpm supervisor; do
  if [ -d "log/$d" ]; then
    echo "  OK : log/$d"
  else
    echo "  MISSING -> mkdir log/$d"
    mkdir -p "log/$d"
  fi
done

echo "===== 0.6 django_sample uv sync ====="
cd "$ROOT/www/django_sample" || { echo "FAIL: no www/django_sample"; exit 1; }
ls -la
echo "--- uv sync ---"
uv sync --frozen --no-install-project 2>&1 | tail -20
echo "--- import django ---"
uv run python -c "import django; print(django.get_version())" 2>&1
echo "--- cleanup .venv ---"
rm -rf .venv
echo "done"
