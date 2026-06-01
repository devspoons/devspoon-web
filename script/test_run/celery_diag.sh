#!/usr/bin/env bash
echo "--- compose ps ---"
cd /mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web/compose/web-service/nginx_gunicorn
docker compose --profile celery --profile redis ps
echo "--- celery-app logs (last 60) ---"
docker compose logs --tail=60 celery 2>&1
echo "--- celerybeat-app logs ---"
docker compose logs --tail=40 celery-beat 2>&1
