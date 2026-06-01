#!/usr/bin/env bash
echo "--- nginx error log tail ---"
docker exec nginx-php-webserver tail -30 /log/nginx/error.log 2>&1
echo "--- direct s_client ---"
echo "Q" | openssl s_client -connect 127.0.0.1:443 -servername localhost 2>&1 | head -40
echo "--- curl verbose ---"
curl -vk https://127.0.0.1/ -H "Host: localhost" --max-time 10 2>&1 | head -40
