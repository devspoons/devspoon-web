# aisum-infrakit 통합 테스트 계획서 (test_plan.md)

> **목표**: `compose/`, `config/`, `docker/`, `log/` 의 모든 변경 사항이 docker / docker-compose 기반에서 정상 동작하는지 **WSL 단독으로 자체 완결되게** 검증한다.
> **원칙**: 사용자 개입 최소화 + 자체 제어 불가 항목은 plan 에서 제외. **공인 도메인·외부 인증서 불필요** — 모든 테스트가 `localhost` + self-signed 더미 인증서로 동작.
> **환경**: WSL2 Ubuntu + Docker 29.x + 자유 포트 80 / 443 / 5555 / 63790
> **도메인 의존성**: 없음 — 모든 server block 은 `Host: localhost` 헤더로 매칭, HTTPS 는 컨테이너 내부에서 self-signed 즉시 생성 (Section 5).
> **인터넷 의존성**: 빌드 1회 / 첫 기동 시 필요 — Docker base 이미지 pull, apt/apk, PyPI (`uv pip install`), GitHub (`nginx-ultimate-bad-bot-blocker`). 캐시 후엔 오프라인 가능.
> **사용자 개입**: 0 — 4개 stack 의 `.env` 는 이미 저장소에 커밋되어 있어 별도 설정 불필요.
>
> 더미 앱:
> - `www/django_sample/` — uv-managed Django 4.0.6 (Python **3.14**, requirements.txt 보존, pyproject.toml + uv.lock + .python-version, `legacy-cgi` shim 으로 stdlib `cgi` 호환)
> - `www/php_sample/index.php` — PHP 7.2 단일 파일
>
> **이 plan 에서 제외된 항목** (자체 제어 불가 — README/운영 가이드로 분리):
> - `script/letsencrypt.sh` 실행 검증: 공인 도메인 + 외부 ACME 도달 필요. 정적 grep 검증조차 plan 에서 제거.
> - 런타임 `update-ngxblocker` 갱신: GitHub raw 접근 필요. 이미지 빌드 시점 캐시만 검증.
> - self-signed 의 OCSP stapling 경고: 환경 의존적 관찰이라 합격/불합격 신호로 부적절.

---

## 0. 사전 조건 (Prerequisite Check)

체크리스트 — 테스트 시작 전 1회 확인.

| # | 항목 | 명령 | 합격 기준 |
|---|---|---|---|
| 0.1 | WSL Docker 가용 | `docker version` | Server `Engine` 행 존재 |
| 0.2 | docker compose v2 | `docker compose version` | `Docker Compose version v2.x.x` |
| 0.3 | 포트 충돌 없음 | `ss -lntp \| grep -E ':(80\|443\|5555\|63790)\b'` | 출력 없음 |
| 0.4 | uv 설치 | `command -v uv && uv --version` | `uv 0.x.x` |
| 0.5 | 호스트 `/log` mount 가능 | `ls log/` | 디렉토리 존재 (없으면 `mkdir -p log/{nginx,gunicorn/{,celery,celerybeat},uvicorn/{,celery,celerybeat},uwsgi/{,celery,celerybeat},php-fpm,supervisor}`) |
| 0.6 | django_sample uv 검증 | `cd www/django_sample && uv sync --frozen --no-install-project && uv run python -c "import django"` | 에러 없음 → `rm -rf .venv` |

---

## 1. 스크립트 단독 테스트 (`script/`)

> `script/letsencrypt.sh` 는 공인 도메인 + 외부 ACME 도달이 필요해 본 plan 에서 제외. 운영 가이드(README)로 분리한다.

### 1-A. `script/logrotate/*` (모든 dropin)
| # | 검사 | 방법 | 합격 기준 |
|---|---|---|---|
| 1A.1 | dropin 파일 syntax | 각 stack 컨테이너에서 `logrotate -d /run/logrotate.d/<file>` | `Handling N logs` + emerg 없음 |
| 1A.2 | nginx dropin 의 USR1 reopen | `docker exec <nginx-container> sh -c "logrotate -f /run/logrotate.d/nginx && nginx still running"` | 회전 후에도 nginx master 살아있음 |
| 1A.3 | python apps copytruncate | gunicorn/uvicorn/celery dropin 의 `copytruncate` 키워드 존재 확인 | grep 매치 |
| 1A.4 | uwsgi 본체 logrotate 부재 | `ls script/logrotate/uwsgi/uwsgi 2>&1` | `No such file` (네이티브 회전으로 대체) |

### 1-B. `config/web-server/nginx/<stack>/nginx_conf.sh` & `nginx_https_conf.sh`
| # | 검사 | 방법 | 합격 기준 |
|---|---|---|---|
| 1B.1 | 비대화형 HTTP 생성 (gunicorn) | `cd config/web-server/nginx/gunicorn && ./nginx_conf.sh -w django_sample -p 80 -d test.local -a gunicorn-app -s 8000 -n autotest_http` | `생성 완료: ./conf.d/autotest_http_gunicorn_ng.conf` |
| 1B.2 | 비대화형 HTTPS 생성 (gunicorn) | `./nginx_https_conf.sh -w django_sample -p 80 -d test.local -a gunicorn-app -s 8000 -n autotest_https` | `생성 완료: ./conf.d/autotest_https_gunicorn_https_ng.conf` |
| 1B.3 | placeholder 모두 치환 | `grep -E '(domain\|appname\|webroot\|portnumber\|filename\|serviceport)' conf.d/autotest_*_ng.conf` | 매치 0건 (모두 실제 값으로 치환) |
| 1B.4 | 동일을 4개 stack 반복 | uvicorn/uwsgi/php 각각 같은 절차 | 모두 통과 |
| 1B.5 | 잘못된 입력 거부 | `./nginx_conf.sh -w x -p 99999 -d X -a Y -s Z` | exit 2 + 형식 오류 메시지 |
| 1B.6 | **정리** | `rm conf.d/autotest_*` | 테스트 산출물 제거 |

---

## 2. Dockerfile 빌드 테스트 (`docker/`)

| # | Dockerfile | 명령 | 합격 기준 |
|---|---|---|---|
| 2.1 | nginx | `docker build -t aisum-test/nginx docker/nginx/` | `naming to docker.io/aisum-test/nginx` |
| 2.2 | gunicorn | `docker build -t aisum-test/gunicorn docker/gunicorn/` | 빌드 성공 (Python 3.14 컴파일 시간 ~5–10분) |
| 2.3 | uwsgi | `docker build -t aisum-test/uwsgi docker/uwsgi/` | 빌드 성공 |
| 2.4 | php-fpm | `docker build -t aisum-test/php-fpm docker/php-fpm/` | 빌드 성공 |

### 2-A. 컨테이너 내부 검사 (각 이미지마다 1회)
| # | 검사 | 명령 | 합격 기준 |
|---|---|---|---|
| 2A.1 | logrotate 설치 | `docker run --rm <img> logrotate --version` | `logrotate 3.x.x` |
| 2A.2 | cron 설치 | `docker run --rm <img> sh -c "command -v cron"` | 경로 출력 |
| 2A.3 | crontab 등록 | `docker run --rm <img> crontab -l` | `0 2 * * * /usr/local/bin/aisum-logrotate.sh` 행 존재 |
| 2A.4 | with-cron.sh 존재 (gunicorn/uwsgi/php-fpm만) | `docker run --rm <img> ls /usr/local/bin/with-cron.sh /usr/local/bin/aisum-logrotate.sh` | 두 파일 모두 존재 + 실행권한 |
| 2A.5 | nginx 의 entrypoint hook | `docker run --rm <nginx-img> ls /docker-entrypoint.d/40-start-cron.sh` | 파일 존재 + 실행권한 |
| 2A.6 | nginx certbot | `docker run --rm <nginx-img> certbot --version` | `certbot 2.x.x` |
| 2A.7 | gunicorn 이미지의 uv | `docker run --rm aisum-test/gunicorn uv --version` | `uv 0.x.x` |
| 2A.8 | gunicorn 이미지 Python | `docker run --rm aisum-test/gunicorn python --version` | `Python 3.14.x` |
| 2A.9 | gunicorn 이미지 cgi shim | `docker run --rm aisum-test/gunicorn python -c "import cgi; assert 'site-packages' in cgi.__file__, cgi.__file__" && docker run --rm aisum-test/gunicorn pip show legacy-cgi \| grep -E '^Name: legacy-cgi'` | 첫 명령 exit 0 (`cgi.__file__` 가 site-packages 안 → stdlib 가 아닌 shim 사용) + 두 번째 명령 `Name: legacy-cgi` 출력 (PyPI shim 설치 확인) |
| 2A.10 | uwsgi 이미지 Python | `docker run --rm --entrypoint /bin/sh aisum-test/uwsgi -c "python --version"` | `Python 3.14.x` |

> Python 3.14 통일 정책: 호스트 django_sample / 모든 컨테이너 모두 3.14 사용. Python 3.13 에서 stdlib `cgi` 모듈이 제거(PEP 594) 되었으므로 Django 4.0.6 의 `import cgi` 호환을 위해 `legacy-cgi` PyPI shim 을 Dockerfile / pyproject.toml 에 추가 (requirements.txt 는 변경 없음).

---

## 3. Stack 통합 테스트 (`compose/`)

각 스택마다 동일 절차. 4회 반복(gunicorn → uvicorn → uwsgi → php).

### 3-A. 사전 — 도메인 conf 준비
- gunicorn/uvicorn/uwsgi: 기존 `django_sample_<stack>_ng.conf` 사용 (server_name `localhost`, host validation 통과 가능)
- php: 기존 `sample_php_ng.conf` 사용 (server_name `localhost`)

### 3-B. 기동 → smoke → 종료 (스택당)
| # | 검사 | 명령 | 합격 기준 |
|---|---|---|---|
| 3B.1 | `.env` 존재 확인 (커밋된 파일 사용) | `cat compose/web-service/nginx_<stack>/.env` | `LOG_DRIVER`, `LOG_OPT_MAXF`, `LOG_OPT_MAXS`, `PROJECT_DIR`, `FLOWER_ID`, `FLOWER_PWD` 모두 정의됨 |
| 3B.2 | 빌드 + 기동 | `cd compose/web-service/nginx_<stack> && docker compose up -d --build` | 모든 서비스 `Up` (또는 `healthy`) |
| 3B.3 | 컨테이너 상태 | `docker compose ps` | webserver, app 모두 `running` |
| 3B.4 | nginx config 검증 (컨테이너 내부) | `docker compose exec webserver nginx -t` | `syntax is ok` + `test is successful` |
| 3B.5 | HTTP 200 (Host: localhost) | `curl -sS -H "Host: localhost" -o /dev/null -w "%{http_code}\n" http://127.0.0.1/` | `200` 단정 (`ALLOWED_HOSTS=['*']` + nginx `server_name localhost` 로 결정됨) |
| 3B.6 | Host 인젝션 차단 | `curl -sS -o /dev/null -w "%{http_code}\n" -H "Host: evil.com" http://127.0.0.1/` | `000` (444 TCP close — curl 는 `Empty reply from server` exit 52) |
| 3B.8 | bad-bot 차단 (ngxblocker, blockbots.conf) | `curl -sS -A "MJ12bot" -o /dev/null -w "%{http_code}\n" -H "Host: localhost" http://127.0.0.1/` | `000` (444 TCP close, curl exit 52) |
| 3B.8a | bad-bot 차단 (다중 UA) | `for ua in AhrefsBot SemrushBot DotBot; do curl -sS -A "$ua" -o /dev/null -w "%{http_code} $ua\n" -H "Host: localhost" http://127.0.0.1/; done` | 3건 모두 `000` (444 close) |
| 3B.8b | ngxblocker.d 명시 include 로딩 | `docker compose exec webserver ls /etc/nginx/ngxblocker.d/` | `botblocker-nginx-settings.conf` + `globalblacklist.conf` 두 파일 존재 |
| 3B.8c | bots.d 차단 리스트 로딩 | `docker compose exec webserver ls /etc/nginx/bots.d/` | `blockbots.conf`, `ddos.conf`, `whitelist-{domains,ips}.conf`, `blacklist-{ips,user-agents}.conf` 등 |
| 3B.8d | update-ngxblocker cron 등록 | `docker compose exec webserver crontab -l \| grep update-ngxblocker` | `0 */6 * * * /usr/local/sbin/update-ngxblocker -nq -c /etc/nginx/ngxblocker.d -b /etc/nginx/bots.d ...` 라인 출력 |
| 3B.8f | 정상 UA 통과 | `curl -sS -A "Mozilla/5.0" -o /dev/null -w "%{http_code}\n" -H "Host: localhost" http://127.0.0.1/` | `200` (앱 정상) 또는 `502` (앱 미기동) — `444/000` 이 아니어야 함 |
| 3B.9 | static 서빙 (django stacks) | `curl -sS -H "Host: localhost" -o /dev/null -w "%{http_code}\n" http://127.0.0.1/static/admin/css/base.css` | `200` |
| 3B.10 | dotfile 차단 | `curl -sS -H "Host: localhost" -o /dev/null -w "%{http_code}\n" http://127.0.0.1/.git/config` | `403` |
| 3B.11 | 보안 헤더 존재 | `curl -sI -H "Host: localhost" http://127.0.0.1/ \| grep -iE '(content-security-policy\|x-content-type-options\|referrer-policy)'` | 3개 헤더 모두 존재 |
| 3B.12 | 호스트 마운트 로그 생성 | `ls log/nginx/*.log \| head` | `*_access_http.log`, `*_error_http.log` 패턴 존재 |
| 3B.13 | 컨테이너 내부 cron 동작 | `docker compose exec webserver pgrep -a cron` | PID 1자리 또는 임의 PID 출력 |
| 3B.14 | logrotate dropin sanitize | `docker compose exec webserver ls -l /run/logrotate.d/nginx` | mode `-rw-r--r--` (0644) |
| 3B.15 | logrotate dry-run | `docker compose exec webserver /usr/sbin/logrotate -d /run/logrotate.d/nginx 2>&1 \| tail -5` | `Handling 1 logs` |
| 3B.16 | 종료 | `docker compose down -v` | 컨테이너/네트워크 제거 (`-v` 로 볼륨도 제거) |

### 3-C. 스택별 추가 검증
| 스택 | 추가 검사 |
|---|---|
| **gunicorn** | `docker compose exec gunicorn-app python -c "import django; print(django.get_version())"` → `4.0.6` |
| **uvicorn** | 동일 (uvicorn-app 컨테이너) |
| **uwsgi** | (1) `docker compose exec uwsgi-app cat /log/uwsgi/django_sample-uwsgi.log` 존재 (2) `docker compose exec uwsgi-app grep -E '^(log-maxsize\|log-reopen)' /application/uwsgi.ini` → 2줄 출력 (네이티브 회전 활성) |
| **php** | `curl -sS -H "Host: localhost" http://127.0.0.1/index.php` → PHP 출력 (예: `<?php echo …;`) |

### 3-D. profile 별 추가 검증 (gunicorn/uvicorn/uwsgi)
| # | 검사 | 명령 | 합격 기준 |
|---|---|---|---|
| 3D.1 | `--profile celery` 기동 | `docker compose --profile celery up -d` | celery, celery-beat, flower 모두 running |
| 3D.2 | flower UI 접근 | `curl -sS -u $FLOWER_ID:$FLOWER_PWD -o /dev/null -w "%{http_code}\n" http://127.0.0.1:5555/` | `200` (basic auth 통과) |
| 3D.3 | celery 로그 파일 생성 | `ls log/<stack>/celery/*.log` | 파일 존재 |
| 3D.4 | `--profile redis` 기동 | `docker compose --profile redis up -d` | redis-stats 실행 |
| 3D.5 | redis-stats UI | `curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:63790/` | `200` |

---

## 4. logrotate / cron 통합 검증 (Docker 컨테이너 내부)

스택 기동 상태에서 1회 — 모든 스택 공통.

| # | 검사 | 명령 | 합격 기준 |
|---|---|---|---|
| 4.1 | 권한 정리 (sanitize) 동작 | `docker compose exec webserver ls -l /etc/logrotate.d/nginx /run/logrotate.d/nginx` | etc 는 0777, run 은 0644 |
| 4.2 | 강제 회전 (force) | `docker compose exec webserver /usr/local/bin/aisum-logrotate.sh && ls /log/nginx/` | 회전된 .gz 또는 .1 파일 출현 (압축은 다음 회전에 적용) |
| 4.3 | nginx 워커 재오픈 | `docker compose exec webserver nginx -s reopen && pgrep -a nginx` | master + workers 살아있음 |
| 4.4 | gunicorn 컨테이너 logrotate | `docker compose exec gunicorn-app /usr/local/bin/aisum-logrotate.sh` | exit 0 |
| 4.5 | uwsgi 네이티브 회전 트리거 | `docker compose exec uwsgi-app sh -c "head -c 105M </dev/urandom > /log/uwsgi/django_sample-uwsgi.log; sleep 2; ls /log/uwsgi/django_sample-uwsgi.log*"` | `<file>.<timestamp>` 파일 추가 출현 (uwsgi가 회전) |

> 4.5는 105MB 더미 데이터 생성으로 디스크 점유. 검증 후 `rm /log/uwsgi/django_sample-uwsgi.log*` 정리.

---

## 5. HTTPS / SSL 검증 (도메인 없이 self-signed 더미 cert 로 진행)

> 모든 HTTPS 검증은 `localhost` 만 대상으로 한다. 기존 `infra.hothada_*_https_ng.conf` 등 다른 server_name 의 conf 는 5.0 의 일괄 cert 생성으로 nginx -t 가 통과되게만 보장하고 실제 트래픽 검사 대상으로는 삼지 않는다.
> 운영 환경에서 공인 인증서를 발급하는 절차는 README/운영 가이드로 분리.

### 5-A. 사전 — `localhost` HTTPS conf 생성 (스택당, compose up 이전)
```bash
cd config/web-server/nginx/<stack>
./nginx_https_conf.sh -w django_sample -p 80 -d localhost -a <stack>-app -s 8000 -n localhost
# → conf.d/localhost_<stack>_https_ng.conf 생성 (server_name localhost)
```
php 스택은 webroot/app/serviceport 인자만 다르게 (`-w php_sample -a php -s 9000`).

### 5-B. 검증 (compose up -d 이후, 스택당 동일 절차)

| # | 검사 | 명령 | 합격 기준 |
|---|---|---|---|
| 5.0 | **conf.d 에 참조된 모든 cert 일괄 self-signed 생성 + nginx -t** | `docker compose exec webserver sh -c 'set -e; for p in $(grep -hE "^\s*ssl_certificate\s" /etc/nginx/conf.d/*.conf \| awk "{print \$2}" \| sed "s/;//" \| sort -u); do d=$(dirname "$p"); cn=$(basename "$d"); mkdir -p "$d" /etc/ssl/certs/"$cn"; [ -f "$p" ] \|\| openssl req -x509 -nodes -newkey rsa:2048 -days 1 -subj "/CN=$cn" -keyout "$d/privkey.pem" -out "$d/fullchain.pem" 2>/dev/null; cp -f "$d/fullchain.pem" "$d/chain.pem"; [ -f /etc/ssl/certs/"$cn"/dhparam.pem ] \|\| openssl dhparam -out /etc/ssl/certs/"$cn"/dhparam.pem 2048 2>/dev/null; done; nginx -t && nginx -s reload'` | `test is successful` 및 `signal process started` |
| 5.1 | TLS 핸드셰이크 (self-signed, SNI=localhost) | `openssl s_client -connect 127.0.0.1:443 -servername localhost </dev/null 2>&1 \| grep -E "(Protocol\|Cipher)"` | `Protocol : TLSv1.3` 또는 `TLSv1.2`, `Cipher: ECDHE-...` |
| 5.2 | HSTS 헤더 (HTTPS) | `curl -sIk https://127.0.0.1/ -H "Host: localhost" --resolve localhost:443:127.0.0.1 \| grep -i strict-transport-security` | `max-age=63072000; includeSubDomains; preload` |
| 5.3 | 80→443 redirect | `curl -sI -H "Host: localhost" http://127.0.0.1/foo \| grep -E "(HTTP/.*301\|Location:)"` | 301 + `Location: https://localhost/foo` |
| 5.4 | 알 수 없는 SNI 거부 (ssl_reject_handshake) | `curl -k --resolve evil.example:443:127.0.0.1 https://evil.example/ 2>&1 \| head -3` | `tlsv1 alert handshake failure` 또는 `SSL_ERROR_SSL` 류 메시지 (성공 응답이 아닌 것을 확인) |

---

## 6. 회귀 (Regression) — 기존 패치 사항 점검

이전 리뷰에서 수정한 항목이 살아있는지 spot-check.

| # | 항목 | 명령 | 합격 기준 |
|---|---|---|---|
| 6.1 | host injection 정규식 버그 (이전: `(com\|kr\|...)`) | `grep -rE 'domain\\\.\\\(com' config/web-server/` | 매치 0 |
| 6.2 | CSP frame-ancestors 통일 | `grep -rE "frame-ancestors '?self'?[^;]*;" config/web-server/ \| grep -v "'self';" \| grep -v "'self' " \|\| true` | 비-`'self';` 형태 0 |
| 6.3 | 로그 파일명 `_(http\|https).log` 끝 | `grep -rE "_(http\|https)_(access\|error)\.log" config/web-server/` | 매치 0 (이전 패턴 없음) |
| 6.4 | LF 라인엔딩 유지 | `find . -type f -not -path './.git/*' -not -path './.claude/*' \| xargs file \| grep -i CRLF \| wc -l` | `0` |
| 6.5 | host 헤더 검증 활성화 | `grep -nE '^\s*if\s*\(\$host\s*!~' config/web-server/nginx/gunicorn/sample_nginx.conf` | 라인 존재 (주석이 아닌 코드 라인으로 `if ($host !~ ...)` 패턴 매칭) |
| 6.6 | uwsgi 네이티브 회전 | `grep -E '^(log-maxsize\|log-reopen)' config/app-server/uwsgi/uwsgi.ini` | 2줄 |
| 6.7 | django_sample uv 전용 | `grep -E '\[tool\.poetry\]' www/django_sample/pyproject.toml` | 매치 0 |
| 6.8 | django_sample Python 3.14 핀 | `cat www/django_sample/.python-version` | `3.14` |
| 6.9 | django_sample legacy-cgi shim | `grep legacy-cgi www/django_sample/pyproject.toml` | `legacy-cgi>=2.6` 라인 존재 |

---

## 7. 정리 (Cleanup) — 모든 테스트 종료 후

| # | 작업 | 명령 |
|---|---|---|
| 7.1 | 모든 stack 종료 + 볼륨 제거 | `for s in nginx_gunicorn nginx_uvicorn nginx_uwsgi nginx_php; do (cd compose/web-service/$s && docker compose --profile celery --profile redis down -v); done` |
| 7.2 | 테스트 이미지 제거 | `docker rmi aisum-test/nginx aisum-test/gunicorn aisum-test/uwsgi aisum-test/php-fpm 2>/dev/null \|\| true` |
| 7.3 | 댕글링 정리 | `docker system prune -f` |
| 7.4 | 로그 디렉토리 비우기 (선택) | `rm -rf log/{nginx,gunicorn,uvicorn,uwsgi,php-fpm}/*` (호스트 권한 확인) |
| 7.5 | django_sample .venv 흔적 (있으면) | `rm -rf www/django_sample/.venv` |

---

## 8. 자동화 스크립트 권장 골격

`scripts/` 같은 별도 디렉토리에 다음 스크립트를 두면 사용자 1회 실행으로 전체 검증 가능:

```bash
# tests/run_all.sh (예시)
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"

stage() { echo; echo "============ $* ============"; }

stage "0. Prereq"
docker version >/dev/null
docker compose version | head -1

stage "1. Scripts standalone"
# logrotate dropin 정적 점검은 컨테이너 내부에서 실행되므로 스킵 (Stack 단계에서 수행)

stage "2. Build images"
for d in nginx gunicorn uwsgi php-fpm; do
    docker build -t aisum-test/$d "$ROOT/docker/$d/"
done

stage "3. Stack smokes"
for stack in nginx_gunicorn nginx_uvicorn nginx_uwsgi nginx_php; do
    cd "$ROOT/compose/web-service/$stack"
    docker compose up -d --build
    docker compose exec -T webserver nginx -t
    code=$(curl -sS -H "Host: localhost" -o /dev/null -w "%{http_code}" http://127.0.0.1/)
    echo "  $stack HTTP code: $code"
    docker compose down -v
done

stage "7. Cleanup"
docker rmi aisum-test/{nginx,gunicorn,uwsgi,php-fpm} 2>/dev/null || true
docker system prune -f >/dev/null
```

---

## 점검표 (요약 매트릭스)

| 영역 | 단위 검사 항목 수 | 자동화 가능 | 사용자 개입 |
|---|---|---|---|
| 0. Prerequisite | 6 | 100% | 없음 |
| 1. Scripts (logrotate + nginx_conf 생성기) | 10 | 100% | 없음 |
| 2. Dockerfile build | 8 | 100% | 없음 (대기 시간만) |
| 3. Stack integration | ~20 × 4 = ~80 | 100% | 없음 (.env 커밋됨) |
| 3-D. Profiles | 5 × 3 = 15 | 100% | 없음 (.env 의 FLOWER_ID/PWD 사용) |
| 4. logrotate/cron | 5 | 100% | 없음 |
| 5. HTTPS | 5 × 4 = 20 | 100% | self-signed 더미 cert (자동 생성) |
| 6. Regression | 9 | 100% | 없음 |
| 7. Cleanup | 5 | 100% | 없음 |
| **합계** | **~158 항목** | **100%** | **0** |

> **자체 제어 가능**: 인터넷이 차단된 환경에선 Section 2 의 이미지 빌드 단계 + Section 3 의 첫 기동(`uv pip install`) 만 1회 캐시가 필요하다. 캐시 이후엔 0~7 전체가 오프라인 자동 수행된다.

---

## 변경 사항 → 검증 항목 매핑 (Traceability)

| 변경 사항 (이전 작업) | 검증 항목 |
|---|---|
| `crontab_*_set.sh` 삭제 + nginx 컨테이너 cron 정상 | 2A.3, 2A.5, 4.1–4.4 |
| 전체 LF 변환 + `.gitattributes` | 6.4 |
| README 다이어그램 정렬 | (수동 확인 — pull request 리뷰) |
| `infra.hothada` HTTP/HTTPS conf | 1B.1, 1B.2, 6.5 |
| 모든 nginx CSP `'self'` 통일 | 6.2, 3B.11 |
| logrotate Dockerfile 보강 + sanitize 패턴 | 2A.1–2A.5, 4.1, 4.4 |
| uwsgi 네이티브 회전 (`log-maxsize`) | 4.5, 6.6, 3-C uwsgi |
| nginx 설정 production 강화 (host validation, Permissions-Policy) | 3B.6, 5.4, 3B.11, 6.1, 6.5 |
| 로그 파일명 `_<type>_<protocol>` 통일 | 3B.12, 6.3 |
| django_sample uv 전용 (Python 3.14 + legacy-cgi shim) | 0.6, 6.7, 6.8, 6.9, 2A.9, 3-C gunicorn (django import) |
| compose `command:` poetry → uv | 3B.2, 3-C 모든 스택 |
