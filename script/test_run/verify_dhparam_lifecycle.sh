#!/usr/bin/env bash
# Standalone dhparam backup/restore behavior test.
# Spins up the nginx image with an empty host backup dir, verifies hook copies
# image→backup; then mutates the host backup, restarts, verifies container picks
# up the mutated host backup (restore-on-restart wins).
set -e

WORK=/tmp/dhparam-test
rm -rf "$WORK"
mkdir -p "$WORK/backup"

cleanup() {
  for c in dhparam-test-1 dhparam-test-2 dhparam-test-3; do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "=== STEP A: empty backup dir, first run (hook should back up image→host) ==="
docker run -d --name dhparam-test-1 \
  -v "$WORK/backup":/etc/nginx/dhparam-backup \
  -p 18080:80 \
  devspoon-nginx:latest >/dev/null
sleep 3
echo "Host backup dir contents:"
ls -la "$WORK/backup/"
SHA_IMG=$(docker exec dhparam-test-1 sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
SHA_HOST=$(sha256sum "$WORK/backup/dhparam.pem" | awk '{print $1}')
echo "  container dhparam sha256: $SHA_IMG"
echo "  host backup  dhparam sha256: $SHA_HOST"
if [ "$SHA_IMG" = "$SHA_HOST" ]; then
  echo "  [PASS-A] image dhparam was backed up to host on first run"
else
  echo "  [FAIL-A] container and host backup differ"
  exit 1
fi
docker rm -f dhparam-test-1 >/dev/null

echo
echo "=== STEP B: stop+rerun with the same host backup (hook should restore host→container) ==="
docker run -d --name dhparam-test-2 \
  -v "$WORK/backup":/etc/nginx/dhparam-backup \
  -p 18081:80 \
  devspoon-nginx:latest >/dev/null
sleep 3
SHA_REBOOT=$(docker exec dhparam-test-2 sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
echo "  container dhparam sha256 after restart: $SHA_REBOOT"
if [ "$SHA_REBOOT" = "$SHA_HOST" ]; then
  echo "  [PASS-B] container has the host backup value after restart"
else
  echo "  [FAIL-B] container did not pick up host backup"
  exit 1
fi
docker rm -f dhparam-test-2 >/dev/null

echo
echo "=== STEP C: replace host backup with a different key, restart, host should win ==="
echo "  Generating new dhparam (small 1024-bit for speed)..."
openssl dhparam -out "$WORK/backup/dhparam.pem" 1024 2>/dev/null
SHA_NEW=$(sha256sum "$WORK/backup/dhparam.pem" | awk '{print $1}')
echo "  new host dhparam sha256: $SHA_NEW (was $SHA_HOST)"
docker run -d --name dhparam-test-3 \
  -v "$WORK/backup":/etc/nginx/dhparam-backup \
  -p 18082:80 \
  devspoon-nginx:latest >/dev/null
sleep 3
SHA_C=$(docker exec dhparam-test-3 sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
echo "  container dhparam sha256: $SHA_C"
if [ "$SHA_C" = "$SHA_NEW" ]; then
  echo "  [PASS-C] host backup wins on restore (image dhparam was overwritten)"
else
  echo "  [FAIL-C] container has image dhparam, host backup ignored"
  exit 1
fi

echo
echo "=== ALL PASS: dhparam backup/restore mechanism works as designed ==="
