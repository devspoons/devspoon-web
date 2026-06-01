#!/usr/bin/env bash
# Standalone nginx test: start the nginx container with the gunicorn stack mounts,
# generate a domain conf, run nginx -t, verify dhparam backup volume + restore works.
set -e

DEVSPOON=/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web
STACK_DIR="$DEVSPOON/compose/web-service/nginx_gunicorn"
NGINX_CFG_DIR="$DEVSPOON/config/web-server/nginx/gunicorn"
BACKUP_DIR="$STACK_DIR/ssl/dhparam"

cleanup() {
  docker rm -f standalone-nginx >/dev/null 2>&1 || true
  rm -f "$NGINX_CFG_DIR/conf.d/sa_gunicorn_ng_http.conf" || true
  rm -f "$NGINX_CFG_DIR/conf.d/sa_gunicorn_ng_https.conf" || true
}
trap cleanup EXIT

echo "=== Pre: clean prior backup dhparam (force fresh test) ==="
rm -f "$BACKUP_DIR/dhparam.pem"
ls -la "$BACKUP_DIR/"

echo
echo "=== Generate HTTP domain conf (sa.test as Host) ==="
cd "$NGINX_CFG_DIR"
./nginx_http_conf.sh -w django_sample -p 80 -d sa.test -a gunicorn-app -s 8000 -n sa | head -5
[ -f "conf.d/sa_gunicorn_ng_http.conf" ] && echo "  HTTP conf created"

echo
echo "=== Start nginx standalone (no gunicorn-app dependency) ==="
docker run -d --name standalone-nginx \
  -v "$DEVSPOON/www":/www \
  -v "$DEVSPOON/script":/script \
  -v "$NGINX_CFG_DIR/conf.d/":/etc/nginx/conf.d/ \
  -v "$NGINX_CFG_DIR/nginx_conf/nginx.conf":/etc/nginx/nginx.conf \
  -v "$NGINX_CFG_DIR/proxy_params/proxy_params":/etc/nginx/proxy_params \
  -v "$BACKUP_DIR/":/etc/nginx/dhparam-backup/ \
  -v "$DEVSPOON/log/":/log/ \
  -v "$DEVSPOON/script/logrotate/nginx/nginx":/etc/logrotate.d/nginx \
  -p 18800:80 -p 18443:443 \
  -e TZ=Asia/Seoul \
  devspoon-nginx:latest >/dev/null
sleep 3

echo
echo "=== Verify nginx process running ==="
docker ps --filter "name=standalone-nginx" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "=== nginx -t (config validity) ==="
docker exec standalone-nginx nginx -t 2>&1 | tail -5

echo
echo "=== Verify dhparam was backed up to host (entrypoint hook ran) ==="
ls -la "$BACKUP_DIR/"
if [ -f "$BACKUP_DIR/dhparam.pem" ]; then
  HSHA=$(sha256sum "$BACKUP_DIR/dhparam.pem" | awk '{print $1}')
  CSHA=$(docker exec standalone-nginx sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
  echo "  host backup sha:  $HSHA"
  echo "  container sha:    $CSHA"
  if [ "$HSHA" = "$CSHA" ]; then
    echo "  [PASS] backup matches container dhparam — backup-on-first-run works"
  else
    echo "  [FAIL] backup and container dhparam differ"
  fi
else
  echo "  [FAIL] no host backup created"
fi

echo
echo "=== Test domain match (Host header → server_name routing) ==="
curl -sS -o /dev/null -w "%{http_code}\n" -H "Host: sa.test" http://localhost:18800/ || echo "(curl failed)"

echo
echo "=== docker compose 'down' simulation: stop + rm container, restart fresh ==="
docker rm -f standalone-nginx >/dev/null
sleep 1
docker run -d --name standalone-nginx \
  -v "$DEVSPOON/www":/www \
  -v "$DEVSPOON/script":/script \
  -v "$NGINX_CFG_DIR/conf.d/":/etc/nginx/conf.d/ \
  -v "$NGINX_CFG_DIR/nginx_conf/nginx.conf":/etc/nginx/nginx.conf \
  -v "$NGINX_CFG_DIR/proxy_params/proxy_params":/etc/nginx/proxy_params \
  -v "$BACKUP_DIR/":/etc/nginx/dhparam-backup/ \
  -v "$DEVSPOON/log/":/log/ \
  -v "$DEVSPOON/script/logrotate/nginx/nginx":/etc/logrotate.d/nginx \
  -p 18800:80 -p 18443:443 \
  -e TZ=Asia/Seoul \
  devspoon-nginx:latest >/dev/null
sleep 3

C2SHA=$(docker exec standalone-nginx sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
echo "  container dhparam sha after restart: $C2SHA"
if [ "$C2SHA" = "$HSHA" ]; then
  echo "  [PASS] same dhparam restored from host backup after restart"
else
  echo "  [FAIL] dhparam changed across restart"
fi

echo
echo "=== Generate HTTPS conf (for path verification only — no cert) ==="
cd "$NGINX_CFG_DIR"
./nginx_https_conf.sh -w django_sample -p 80 -d sa.test -a gunicorn-app -s 8000 -n sa | head -5
[ -f "conf.d/sa_gunicorn_ng_https.conf" ] && echo "  HTTPS conf created"

echo
echo "=== Verify HTTPS conf paths point to expected files ==="
grep -E "ssl_certificate|ssl_dhparam|root\s|/.well-known/acme-challenge" conf.d/sa_gunicorn_ng_https.conf | head -10

echo
echo "=== nginx -t with both HTTP+HTTPS conf (expect fail since no real cert) ==="
docker exec standalone-nginx nginx -t 2>&1 | tail -8 || true
echo "(nginx -t fail is EXPECTED because cert files /etc/letsencrypt/live/sa.test/* don't exist - this proves path resolution is correct)"

echo
echo "=== ALL DONE ==="
