#!/usr/bin/env bash
# verify the exit code of the invalid-input scripts
ROOT="/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web"
for stack in gunicorn uvicorn uwsgi php; do
    cd "$ROOT/config/web-server/nginx/$stack" || continue
    echo "--- $stack nginx_http_conf.sh invalid ---"
    ./nginx_http_conf.sh -w x -p 99999 -d X -a Y -s Z >/tmp/out 2>/tmp/err
    ec=$?
    echo "exit=$ec"
    echo "stdout:"; cat /tmp/out
    echo "stderr:"; cat /tmp/err
    echo
done
