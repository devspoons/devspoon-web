#!/usr/bin/env bash
for c in nginx-daphne-webserver daphne-app redis_db uvicorn-app nginx-uvicorn-webserver; do
  echo "=== $c ==="
  docker inspect "$c" --format 'project={{ index .Config.Labels "com.docker.compose.project" }} cfg={{ index .Config.Labels "com.docker.compose.project.config_files" }} status={{ .State.Status }}' 2>&1
done
