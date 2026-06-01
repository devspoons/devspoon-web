#!/usr/bin/env bash
# Section 5 HTTPS verification on the currently running stack
set +e
ROOT="/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web"
STACK_DIR="$1"        # nginx_php-7.3 / nginx_php-8.4 / nginx_gunicorn / nginx_uvicorn / nginx_uwsgi / nginx_daphne
STACK="$2"            # php / gunicorn etc.
WEBROOT="$3"          # php_sample / django_sample
APPNAME="$4"          # php-app / gunicorn-app
SPORT="$5"            # 9000 / 8000

NGINX_DIR="$ROOT/config/web-server/nginx/$STACK"

cd "$NGINX_DIR" || { echo "FAIL cd to $NGINX_DIR"; exit 1; }

# 5-A: generate localhost https conf
echo "===== 5-A generate localhost HTTPS conf for $STACK ====="
./nginx_https_conf.sh -w "$WEBROOT" -p 80 -d localhost -a "$APPNAME" -s "$SPORT" -n localhost 2>&1 | tail -5
ls conf.d/localhost_${STACK}_https_ng.conf

cd "$ROOT/compose/web-service/$STACK_DIR" || { echo "FAIL cd"; exit 1; }

# 5.0: generate self-signed cert and reload nginx
echo "===== 5.0 self-signed cert + nginx -t + reload ====="
docker compose exec -T webserver sh -c '
set -e
for p in $(grep -hE "^[[:space:]]*ssl_certificate[[:space:]]" /etc/nginx/conf.d/*.conf | awk "{print \$2}" | sed "s/;//" | sort -u); do
    d=$(dirname "$p")
    cn=$(basename "$d")
    mkdir -p "$d"
    if [ ! -f "$p" ]; then
        openssl req -x509 -nodes -newkey rsa:2048 -days 1 -subj "/CN=$cn" -keyout "$d/privkey.pem" -out "$d/fullchain.pem" 2>/dev/null
    fi
    cp -f "$d/fullchain.pem" "$d/chain.pem"
    # dhparam(ssl_dhparam)은 이미지에 구워진 /etc/nginx/dhparam.pem 사용 → 테스트에서 별도 생성 불필요
done
nginx -t && nginx -s reload
' 2>&1 | tail -20

# 5.1 TLS handshake
echo "===== 5.1 TLS handshake ====="
openssl s_client -connect 127.0.0.1:443 -servername localhost </dev/null 2>&1 | grep -E "(Protocol|Cipher)" | head -5

# 5.2 HSTS (use URL with hostname so SNI is set correctly)
echo "===== 5.2 HSTS ====="
curl -sIk --resolve localhost:443:127.0.0.1 https://localhost/ 2>/dev/null | grep -i strict-transport-security

# 5.3 80->443 redirect
echo "===== 5.3 80->443 redirect ====="
curl -sI -H "Host: localhost" http://127.0.0.1/foo 2>/dev/null | grep -E "(HTTP/.*30[12]|Location:)"

# 5.4 unknown SNI
echo "===== 5.4 unknown SNI rejection ====="
curl -k --resolve evil.example:443:127.0.0.1 https://evil.example/ 2>&1 | head -3
