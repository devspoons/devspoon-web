#!/usr/bin/env bash
# Section 2-A: container internal inspections for each image
set +e

check_label() {
    echo ""
    echo "===== $1 ====="
    shift
    "$@"
    echo "  exit=$?"
}

inspect() {
    local img="$1"
    echo ""
    echo "###############  IMAGE: $img  ###############"
    check_label "2A.1 logrotate version" docker run --rm "$img" logrotate --version 2>&1 | head -3
    check_label "2A.2 cron command path" docker run --rm "$img" sh -c "command -v cron || command -v crond"
    check_label "2A.3 crontab -l" docker run --rm "$img" crontab -l 2>&1 | head -10
}

for img in aisum-test/nginx aisum-test/gunicorn aisum-test/uwsgi aisum-test/php-fpm; do
    if docker image inspect "$img" >/dev/null 2>&1; then
        inspect "$img"
    else
        echo "SKIP $img (not built yet)"
    fi
done

echo ""
echo "===== 2A.4 with-cron.sh + aisum-logrotate.sh (gunicorn/uwsgi/php-fpm) ====="
for img in aisum-test/gunicorn aisum-test/uwsgi aisum-test/php-fpm; do
    if docker image inspect "$img" >/dev/null 2>&1; then
        echo "--- $img ---"
        docker run --rm "$img" ls -l /usr/local/bin/with-cron.sh /usr/local/bin/aisum-logrotate.sh 2>&1
    else
        echo "SKIP $img"
    fi
done

echo ""
echo "===== 2A.5 nginx entrypoint hook 40-start-cron.sh ====="
if docker image inspect aisum-test/nginx >/dev/null 2>&1; then
    docker run --rm --entrypoint sh aisum-test/nginx -c "ls -l /docker-entrypoint.d/40-start-cron.sh"
fi

echo ""
echo "===== 2A.6 nginx certbot ====="
if docker image inspect aisum-test/nginx >/dev/null 2>&1; then
    docker run --rm --entrypoint certbot aisum-test/nginx --version 2>&1 | head -3
fi

echo ""
echo "===== 2A.7 gunicorn uv version ====="
if docker image inspect aisum-test/gunicorn >/dev/null 2>&1; then
    docker run --rm aisum-test/gunicorn uv --version 2>&1
fi

echo ""
echo "===== 2A.8 gunicorn python --version ====="
if docker image inspect aisum-test/gunicorn >/dev/null 2>&1; then
    docker run --rm aisum-test/gunicorn python --version 2>&1
fi

echo ""
echo "===== 2A.9 gunicorn cgi legacy shim ====="
if docker image inspect aisum-test/gunicorn >/dev/null 2>&1; then
    docker run --rm aisum-test/gunicorn python -c "import cgi, sys; p=cgi.__file__; sys.exit(0 if 'site-packages' in p and 'legacy' in open(p).read(2048).lower() else 1)" 2>&1
    echo "  exit=$?"
fi

echo ""
echo "===== 2A.10 uwsgi python ====="
if docker image inspect aisum-test/uwsgi >/dev/null 2>&1; then
    docker run --rm --entrypoint /bin/sh aisum-test/uwsgi -c "python --version" 2>&1
fi
