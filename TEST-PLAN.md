# devspoon-web 통합 테스트 계획서 (TC 카드 / AI 실행 적합 버전)

본 문서는 사용자가 AI 에게 단일 지시("TC-X 실행", "Phase A 전체", "회귀만 빠르게" 등)로 테스트를 의뢰할 수 있도록 **각 테스트 케이스(TC)가 self-contained 한 카드 형식** 으로 작성되어 있다.

| 항목 | 내용 |
|---|---|
| **대상** | `compose/web_service/{nginx_gunicorn, nginx_uvicorn, nginx_daphne, nginx_uwsgi, nginx_php}` |
| **환경** | WSL2 + Docker Engine + Compose v2 |
| **방식** | 스택을 하나씩 up → 검수 → down 의 순차 실행 |
| **헬퍼** | `script/test/preflight.sh`, `script/test/helpers.sh` |
| **결과 누적** | `/tmp/devspoon-test-results.tsv` (TSV — TC_ID / PHASE / STACK / STATUS / DURATION / TIMESTAMP / NOTES) |
| **Fail-fast** | 기본값 `critical` (Critical: Yes 인 TC FAIL 시 중단). 환경변수 `TEST_FAIL_FAST=always\|critical\|never` 로 변경 |
| **사전 정리** | 각 Phase 진입 전 `pre_phase_cleanup` (helpers.sh) 자동 실행 — 모든 스택 강제 down + 잔존 컨테이너 제거로 포트 충돌 차단 |
| **자체 실행 보장** | 모든 AI EXEC TC 는 외부 도메인/실제 DNS 없이 WSL 단독 실행 가능. 외부 의존 항목은 [부록 D](#부록-d--자체-실행-불가능--외부-의존-항목) 별도 정리 |

---

## 0. 요청 패턴 (User → AI 지시 방법)

다음 다섯 가지 패턴 중 하나로 지시하면 AI 가 해당 TC 들을 순차 실행합니다.

| 요청 예 | AI 가 실행하는 TC | 비고 |
|---|---|---|
| **"preflight 실행"** | `script/test/preflight.sh` | 시작 가능 여부만 점검 (read-only, 30초) |
| **"Phase A 전체"** | TC-A.* (10건) | 4개 Dockerfile 빌드 + 베이스 메타 검증 |
| **"`<stack>` 스택 테스트"** (gun/uvi/dap/uws/php) | TC-B.\<stack\>.* | 해당 스택 up → 검수 → down |
| **"TC-X.Y.NNN 실행"** | 단일 TC | Preconditions 자동 점검 → 부족 시 의존 TC 선행 |
| **"회귀만"** | TC-R.* (8건) | grep 위주, 스택 기동 불필요 (1분) |
| **"Critical FAIL 만 빠르게"** | Critical: Yes 인 TC 만 | 핵심 회귀 + uv 정책 + reload 만 |
| **"전체 실행"** | Preflight → A → B(5스택) → C → U → R → L(옵션) → Z | 약 3-4시간 |

요청 시 추가 옵션을 함께 명시할 수 있다:
- `TEST_FAIL_FAST=always` — 첫 FAIL 즉시 중단
- `SKIP_LOAD=1` — Phase L 건너뜀 (기본)
- `REUSE_BUILDS=1` — Phase A 빌드를 캐시 활용 (재실행 시 빠름)

---

## 1. 스택 변수 매핑 (Stack Variable Map)

| Stack 키 | compose 디렉터리 | nginx 컨테이너 | 앱 컨테이너 | celery 컨테이너 | uv extras | readiness 패턴 |
|---|---|---|---|---|---|---|
| `gun` | `compose/web_service/nginx_gunicorn` | `nginx-gunicorn-webserver` | `gunicorn-app` | `celery-app` | `gunicorn,celery` | `Listening at` |
| `uvi` | `compose/web_service/nginx_uvicorn` | `nginx-uvicorn-webserver` | `uvicorn-app` | `celery-app` | `uvicorn,celery` | `Listening at` |
| `dap` | `compose/web_service/nginx_daphne` | `nginx-daphne-webserver` | `daphne-app` | `celery-app` | `daphne,celery` | `Listening on TCP` |
| `uws` | `compose/web_service/nginx_uwsgi` | `nginx-uwsgi-webserver` | `uwsgi-app` | `celery-app` | `uwsgi,celery` | `WSGI app ... ready in` |
| `php` | `compose/web_service/nginx_php` | `nginx-php-webserver` | `php-app` | (없음) | — | `ready to handle connections` |

이 표의 값은 `script/test/helpers.sh` 의 `stack_meta()` 함수에 동일하게 인코딩되어 있다.

---

## 1.5. 사전 정리 (Pre-Phase Cleanup)

각 Phase (A/B/C/U/L) 진입 전 AI 는 `helpers.sh::pre_phase_cleanup()` 을 자동 호출하여 다음을 보장한다:

```bash
source script/test/helpers.sh
pre_phase_cleanup    # 5개 compose 스택 down + 모든 jvanish 컨테이너 강제 제거
```

이는 **포트 80/443 점유 충돌** (stale uvicorn 스택 등) 으로 인한 후속 TC 실패를 차단한다. 단일 호스트에서는 한 번에 한 스택만 80/443 을 점유할 수 있으므로 본 단계는 필수다 ([부록 D](#부록-d--자체-실행-불가능--외부-의존-항목) "5개 스택 동시 가동" 항목 참조).

---

## 2. TC 카드 인덱스

| Phase | 카테고리 | 개수 | 스택 기동 필요 | 예상 시간 |
|---|---|---|---|---|
| P | Preflight | 1 | ❌ | 30초 |
| A | Image Build | 10 | ❌ | 30-60분 (첫 빌드) / 5분 (캐시) |
| B | Stack (5 sub-stacks × 5~7 each) | 30 | ✅ 스택별 | 10-15분/스택 |
| C | Temporal (cron / reload / logrotate) | 7 | ✅ nginx_gunicorn | 20분 |
| U | uv workflow | 3 | ✅ nginx_gunicorn | 10분 |
| R | Regression | 8 | ❌ | 1분 |
| L | Load (옵션) | 2 | ✅ nginx_gunicorn | 30분 |
| Z | Cleanup | 4 | ❌ | 5분 |

각 TC 카드는 다음 6필드를 가진다:

```
Type:           AI EXEC | USER PREP | OPTIONAL — AI 가 직접 실행 가능한지
Critical:       Yes / No — Critical FAIL 정의 (TEST_FAIL_FAST=critical 시 중단)
Preconditions:  실행 전제 조건 (다른 TC 의 PASS 또는 상태)
Run:            결정론적 명령 시퀀스 (bash, 한 블록)
Pass-if:        통과 조건 (exit code / grep 패턴 / 정확한 값)
On Fail:        STOP_IF_CRITICAL | CONTINUE | SKIP_DOWNSTREAM
Cleanup:        실행 후 원복 필요 사항 (없으면 'none')
```

---

# Phase P — Preflight

## TC-P.001 — 시작 가능 여부 점검

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | Yes |
| Preconditions | 작업 디렉터리가 `devspoon-web/` 루트 |
| On Fail | STOP_IF_CRITICAL |
| Cleanup | none |

**Run:**
```bash
source script/test/helpers.sh
bash script/test/preflight.sh
```

**Pass-if:** exit code = 0 AND 출력 마지막에 `PREFLIGHT PASS` 라인이 있다.

---

# Phase A — Image Build

> Phase A 는 캐시 없이 빌드 (`--no-cache`). 재실행 시 `REUSE_BUILDS=1` 환경변수가 설정되어 있으면 캐시 활용.

## TC-A.001 — gunicorn Dockerfile 빌드

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-P.001 PASS |
| On Fail | SKIP_DOWNSTREAM (TC-B.gun.*) |
| Cleanup | none |

**Run:**
```bash
source script/test/helpers.sh
opt="--no-cache"; [ "${REUSE_BUILDS:-0}" = "1" ] && opt=""
docker build $opt -t devspoon/gunicorn:test docker/gunicorn/ 2>&1 | tail -5
```

**Pass-if:** exit code = 0 AND `Successfully tagged` 또는 `naming to docker.io/devspoon/gunicorn:test` 라인 존재.

---

## TC-A.002 — uwsgi Dockerfile 빌드

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-P.001 PASS |
| On Fail | SKIP_DOWNSTREAM (TC-B.uws.*) |
| Cleanup | none |

**Run:**
```bash
opt="--no-cache"; [ "${REUSE_BUILDS:-0}" = "1" ] && opt=""
docker build $opt -t devspoon/uwsgi:test docker/uwsgi/ 2>&1 | tail -5
```

**Pass-if:** exit code = 0.

---

## TC-A.003 — nginx Dockerfile 빌드

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-P.001 PASS |
| On Fail | SKIP_DOWNSTREAM (Phase B nginx 컨테이너 전체) |
| Cleanup | none |

**Run:**
```bash
opt="--no-cache"; [ "${REUSE_BUILDS:-0}" = "1" ] && opt=""
docker build $opt -t devspoon/nginx:test docker/nginx/ 2>&1 | tail -5
```

**Pass-if:** exit code = 0.

---

## TC-A.004 — php-fpm Dockerfile 빌드

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-P.001 PASS |
| On Fail | SKIP_DOWNSTREAM (TC-B.php.*) |
| Cleanup | none |

**Run:**
```bash
opt="--no-cache"; [ "${REUSE_BUILDS:-0}" = "1" ] && opt=""
docker build $opt -t devspoon/php-fpm:test docker/php-fpm/ 2>&1 | tail -5
```

**Pass-if:** exit code = 0.

---

## TC-A.005 — Ubuntu 24.04 베이스 검증 (gunicorn / uwsgi)

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-A.001, TC-A.002 PASS |
| On Fail | CONTINUE |
| Cleanup | none |

**Run:**
```bash
docker run --rm devspoon/gunicorn:test bash -c "cat /etc/os-release | grep VERSION_ID"
docker run --rm devspoon/uwsgi:test   bash -c "cat /etc/os-release | grep VERSION_ID"
```

**Pass-if:** 양쪽 모두 `VERSION_ID="24.04"` 출력.

---

## TC-A.006 — Python 3.14.0 검증

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-A.001 PASS |
| On Fail | CONTINUE |
| Cleanup | none |

**Run:**
```bash
docker run --rm devspoon/gunicorn:test python --version
docker run --rm devspoon/uwsgi:test   python --version
```

**Pass-if:** 양쪽 모두 `Python 3.14.0` (또는 정확히 빌드된 버전) 출력.

---

## TC-A.007 — uv 설치 검증

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-A.001, TC-A.002 PASS |
| On Fail | STOP_IF_CRITICAL (uv 없으면 후속 정책 모두 무효) |
| Cleanup | none |

**Run:**
```bash
docker run --rm devspoon/gunicorn:test uv --version
docker run --rm devspoon/uwsgi:test   uv --version
```

**Pass-if:** 양쪽 모두 `uv 0\.[0-9]+\.[0-9]+` 형식 출력 (exit 0).

---

## TC-A.008 — UV_PROJECT_ENVIRONMENT ENV 설정 검증 (★ no-venv 정책의 근간)

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | Yes |
| Preconditions | TC-A.001, TC-A.002 PASS |
| On Fail | STOP_IF_CRITICAL |
| Cleanup | none |

**Run:**
```bash
docker run --rm devspoon/gunicorn:test env | grep -E "^UV_(PROJECT_ENVIRONMENT|LINK_MODE|COMPILE_BYTECODE|NO_CACHE)="
echo "---"
docker run --rm devspoon/uwsgi:test   env | grep -E "^UV_(PROJECT_ENVIRONMENT|LINK_MODE|COMPILE_BYTECODE|NO_CACHE)="
```

**Pass-if:** 양쪽 이미지에서 다음 4개 라인이 모두 출력:
- `UV_PROJECT_ENVIRONMENT=/usr/local`
- `UV_LINK_MODE=copy`
- `UV_COMPILE_BYTECODE=1`
- `UV_NO_CACHE=1`

---

## TC-A.009 — gunicorn / celery / uvicorn / uwsgi 시스템 사전 설치

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-A.001, TC-A.002 PASS |
| On Fail | CONTINUE |
| Cleanup | none |

**Run:**
```bash
docker run --rm devspoon/gunicorn:test bash -c "which gunicorn celery uvicorn"
docker run --rm devspoon/uwsgi:test   bash -c "which uwsgi gunicorn celery"
```

**Pass-if:** 모든 바이너리가 `/usr/local/bin/` 경로로 출력.

---

## TC-A.010 — nginx 1.27 + certbot + crontab 등록 검증

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | Yes |
| Preconditions | TC-A.003 PASS |
| On Fail | STOP_IF_CRITICAL |
| Cleanup | none |

**Run:**
```bash
docker run --rm devspoon/nginx:test nginx -v 2>&1
docker run --rm devspoon/nginx:test certbot --version
docker run --rm devspoon/nginx:test crontab -l
```

**Pass-if (3가지 모두):**
- `nginx version: nginx/1\.27\.` 매칭
- `certbot 2\.` 매칭
- crontab 에 `certbot renew` + `nginx -t && nginx -s reload` + `/log/nginx/crontab_` 모두 포함된 라인 존재

---

# Phase B — Stack Tests

## ── Stack #1: nginx_gunicorn (TC-B.gun.*)

### TC-B.gun.001 — 스택 정상 기동

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-A.001, TC-A.003 PASS, 다른 스택 미가동 |
| On Fail | SKIP_DOWNSTREAM (TC-B.gun.*) |
| Cleanup | none (downstream 에서 사용) |

**Run:**
```bash
source script/test/helpers.sh
stack_up gun
docker compose -f $(stack_meta gun dir)/docker-compose.yml ps --format json | jq -r '.[] | .Name + " " + .State'
```

**Pass-if:** 출력에 `nginx-gunicorn-webserver running` 및 `gunicorn-app running` 두 줄 모두 존재.
**Duration:** 첫 빌드 후 ~3-5분 (uv sync 포함), 캐시 후 ~30초.

---

### TC-B.gun.002 — uv no-venv 정책 검증 (★ 핵심)

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | Yes |
| Preconditions | TC-B.gun.001 PASS |
| On Fail | STOP_IF_CRITICAL |
| Cleanup | none |

**Run:**
```bash
source script/test/helpers.sh
assert_no_venv gunicorn-app /www/django_sample
assert_system_python_import gunicorn-app django
docker exec gunicorn-app uv pip list --system 2>/dev/null | grep -iE "^(Django|gunicorn|celery)\s"
```

**Pass-if (3가지 모두):**
- `assert_no_venv` exit 0 (.venv 부재)
- `assert_system_python_import` exit 0 (django 가 /usr/local/lib/python* 에서 로드)
- `uv pip list --system` 출력에 Django, gunicorn, celery 세 줄 모두 존재

---

### TC-B.gun.003 — nginx 라우팅 + 봇 차단 자체검증 (임시 server 블록)

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-B.gun.001 PASS |
| On Fail | CONTINUE |
| Cleanup | self — 임시 server 블록 자동 제거 |

**왜 임시 server 블록?**: 우리 default.conf 는 미일치 Host 를 444 catch-all 로 끊으므로 `curl http://localhost/` 만으로는 nginx 의 실제 라우팅/봇 차단 동작을 검증할 수 없다. Host: blocker.test 매칭하는 임시 server 블록을 주입하면 도메인 설정 없이도 자체 검증이 가능하다.

**Run:**
```bash
CONT=nginx-gunicorn-webserver

# 1) 임시 server 블록 (Host: blocker.test 매칭, ngxblocker include, 200 응답)
cat > /tmp/zz_blocker_test.conf <<'EOF'
server {
    listen 80;
    server_name blocker.test;
    access_log /log/nginx/blocker_test_access.log main;
    include /etc/nginx/bots.d/blockbots.conf;
    include /etc/nginx/bots.d/ddos.conf;
    location / { return 200 "blocker_test_ok\n"; }
}
EOF
docker cp /tmp/zz_blocker_test.conf $CONT:/etc/nginx/conf.d/zz_blocker_test.conf
rm -f /tmp/zz_blocker_test.conf
docker exec $CONT bash -c "nginx -t && nginx -s reload" 2>&1 | tail -2

# 2) 정상 UA → 200 기대
ok_code=$(curl -s -A "Mozilla/5.0" -H "Host: blocker.test" -o /dev/null -w '%{http_code}' --max-time 5 http://localhost/)

# 3) 봇 UA → 444 차단 기대 (444 또는 connection-closed 000)
bot_code=$(curl -s -A "MJ12bot"   -H "Host: blocker.test" -o /dev/null -w '%{http_code}' --max-time 5 http://localhost/)

# 4) 정리 (실패 여부와 무관하게 항상 수행)
docker exec $CONT rm -f /etc/nginx/conf.d/zz_blocker_test.conf
docker exec $CONT bash -c "nginx -t && nginx -s reload" >/dev/null 2>&1

echo "Mozilla=$ok_code MJ12bot=$bot_code"
[ "$ok_code" = "200" ] && { [ "$bot_code" = "444" ] || [ "$bot_code" = "000" ]; }
```

**Pass-if:** `Mozilla=200 MJ12bot=444` (또는 `MJ12bot=000`) 출력 AND exit 0.

---

### TC-B.gun.004 — gunicorn 시작 로그 생성

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-B.gun.001 PASS |
| On Fail | CONTINUE |
| Cleanup | none |

**Note:** access 로그는 실제 도메인 트래픽이 있어야 쌓이므로 본 TC 에서는 검증하지 않는다 (실 환경 검증은 [부록 D](#부록-d--자체-실행-불가능--외부-의존-항목) 참조). 본 TC 는 gunicorn 기동 시 자동 기록되는 error 로그(설정/워커 정보 등)만 확인한다.

**Run:**
```bash
test -s log/gunicorn/gunicorn_error.log && echo "ERROR_LOG_OK"
ls -la log/gunicorn/ log/nginx/
```

**Pass-if:** `ERROR_LOG_OK` 출력.

---

### TC-B.gun.005 — Worker 수 = 9 (8c+1)

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-B.gun.001 PASS |
| On Fail | CONTINUE |
| Cleanup | none |

**Run:**
```bash
n=$(docker exec gunicorn-app bash -c "ps -eo cmd | grep -c '^[^ ]*gunicorn' " 2>/dev/null)
echo "gunicorn processes: $n"
```

**Pass-if:** `n` 이 `10` (master 1 + workers 9). ±1 허용 (`9~11`).

---

### TC-B.gun.006 — Celery profile 기동 + concurrency=8

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-B.gun.001 PASS |
| On Fail | CONTINUE |
| Cleanup | TC-B.gun.007 에서 함께 정리 |

**Run:**
```bash
source script/test/helpers.sh
stack_up_with_celery gun
sleep 5
docker compose -f $(stack_meta gun dir)/docker-compose.yml ps --format json | jq -r '.[].Name'
# celery worker child 프로세스 수 = concurrency
n=$(docker exec celery-app bash -c "ps -eo ppid,cmd | grep -E 'celery.*worker' | grep -v grep | wc -l")
echo "celery worker processes: $n"
ls log/gunicorn/celery/ log/gunicorn/celerybeat/
```

**Pass-if:**
- compose ps 에 `celery-app`, `celerybeat-app`, `flower` 모두 출력
- `celery worker processes` 가 `9` (master 1 + concurrency 8). ±1 허용

---

### TC-B.gun.007 — 스택 정리

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-B.gun.001 PASS (또는 스택 가동 중) |
| On Fail | CONTINUE |
| Cleanup | self |

**Run:**
```bash
source script/test/helpers.sh
stack_down gun
docker ps --filter "name=gunicorn-app" --filter "name=nginx-gunicorn" -q | wc -l
```

**Pass-if:** 마지막 `wc -l` 출력 = `0` (해당 컨테이너 부재).

---

## ── Stack #2: nginx_uvicorn (TC-B.uvi.*)

### TC-B.uvi.001 — 스택 정상 기동

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-A.001, TC-A.003 PASS, 다른 스택 미가동 |
| On Fail | SKIP_DOWNSTREAM (TC-B.uvi.*) |
| Cleanup | none |

**Run:**
```bash
source script/test/helpers.sh
stack_up uvi
docker compose -f $(stack_meta uvi dir)/docker-compose.yml ps --format json | jq -r '.[] | .Name + " " + .State'
```

**Pass-if:** `nginx-uvicorn-webserver running`, `uvicorn-app running` 두 줄 출력.

---

### TC-B.uvi.002 — uv no-venv 정책 검증 (★ 핵심)

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | Yes |
| Preconditions | TC-B.uvi.001 PASS |
| On Fail | STOP_IF_CRITICAL |
| Cleanup | none |

**Run:**
```bash
source script/test/helpers.sh
assert_no_venv uvicorn-app /www/django_sample
assert_system_python_import uvicorn-app django
assert_system_python_import uvicorn-app uvicorn
docker exec uvicorn-app uv pip list --system | grep -iE "^(Django|gunicorn|uvicorn)\s"
```

**Pass-if (모두):**
- .venv 부재
- django + uvicorn 모두 /usr/local/lib/python* 경로
- `pip list` 에 Django, gunicorn, uvicorn 세 줄 동시 존재 (uvicorn extra 가 gunicorn 포함을 검증)

---

### TC-B.uvi.003 — UvicornWorker 8개

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-B.uvi.001 PASS |
| On Fail | CONTINUE |
| Cleanup | none |

**Run:**
```bash
n=$(docker exec uvicorn-app bash -c "ps -eo cmd | grep -c '^[^ ]*gunicorn'")
echo "gunicorn(+UvicornWorker) processes: $n"
```

**Pass-if:** `n` ∈ `[8, 10]` (master 1 + workers 8, ±1 허용).

---

### TC-B.uvi.004 — 설정 경로 분리 검증 (uvicorn.conf.py, 구파일 제거)

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-B.uvi.001 PASS |
| On Fail | CONTINUE |
| Cleanup | none |

**Run:**
```bash
docker exec uvicorn-app ls /uvicorn/
echo "---"
docker exec uvicorn-app test ! -f /uvicorn/gunicorn_uvicorn.conf.py && echo "OLD_NAME_REMOVED"
docker exec uvicorn-app test -f /uvicorn/uvicorn.conf.py && echo "NEW_NAME_OK"
```

**Pass-if:** `OLD_NAME_REMOVED` AND `NEW_NAME_OK` 두 줄 출력.

---

### TC-B.uvi.005 — depends_on 회귀 검증 (gunicorn-uvicorn-app 부재)

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | (없음) |
| On Fail | CONTINUE |
| Cleanup | none |

**Run:**
```bash
grep -c "gunicorn-uvicorn-app" compose/web_service/nginx_uvicorn/docker-compose.yml || true
```

**Pass-if:** 출력 = `0`.

---

### TC-B.uvi.006 — uvicorn 시작 로그 생성

| Field | Value |
|---|---|
| Type | AI EXEC |
| Critical | No |
| Preconditions | TC-B.uvi.001 PASS |
| On Fail | CONTINUE |
| Cleanup | none |

**Note:** access 로그는 실제 도메인 트래픽이 있어야 쌓이므로 본 TC 에서는 검증하지 않는다. gunicorn 마스터(UvicornWorker 호스트)가 기동 시 자동 기록하는 error 로그만 확인.

**Run:**
```bash
test -s log/uvicorn/uvicorn_error.log && echo "ERROR_OK"
```

**Pass-if:** `ERROR_OK` 출력.

---

### TC-B.uvi.007 — 스택 정리

**Run:** `source script/test/helpers.sh; stack_down uvi`
**Pass-if:** `docker ps --filter name=uvicorn-app -q | wc -l` = 0

---

## ── Stack #3: nginx_daphne (TC-B.dap.*)

### TC-B.dap.001 — 스택 정상 기동

**Run:**
```bash
source script/test/helpers.sh
stack_up dap
docker compose -f $(stack_meta dap dir)/docker-compose.yml ps --format json | jq -r '.[] | .Name + " " + .State'
```

**Pass-if:** `nginx-daphne-webserver running`, `daphne-app running` 두 줄.

---

### TC-B.dap.002 — uv no-venv 정책 (★ Critical)

| Critical | Yes |
|---|---|
| Preconditions | TC-B.dap.001 PASS |
| On Fail | STOP_IF_CRITICAL |

**Run:**
```bash
source script/test/helpers.sh
assert_no_venv daphne-app /www/django_sample
assert_system_python_import daphne-app daphne
assert_system_python_import daphne-app channels
```

**Pass-if:** 모두 exit 0.

---

### TC-B.dap.003 — daphne 단일 프로세스

**Run:**
```bash
n=$(docker exec daphne-app bash -c "ps -eo cmd | grep -c '^[^ ]*daphne'")
echo "daphne processes: $n"
```

**Pass-if:** `n` = 1 (daphne 는 단일 프로세스 설계).

---

### TC-B.dap.004 — daphne 시작 로그 생성

**Note:** access 로그는 실제 도메인 트래픽 필요. 본 TC 는 daphne 기동 시 자동 기록되는 stdout/error 로그만 확인.

**Run:**
```bash
test -s log/daphne/stdout.log && echo "STDOUT_OK"
test -s log/daphne/error.log  && echo "ERROR_OK"
```

**Pass-if:** 두 라인 모두 출력.

---

### TC-B.dap.005 — 로그 파일 3종 존재 확인

**Note:** access.log 는 size 0 일 수 있음 (실 도메인 트래픽 부재). 파일 존재 여부만 확인.

**Run:**
```bash
for f in stdout.log error.log access.log; do
  test -f log/daphne/$f && echo "OK $f"
done
```

**Pass-if:** 3줄 모두 `OK` 출력.

---

### TC-B.dap.006 — 스택 정리

**Run:** `source script/test/helpers.sh; stack_down dap`

---

## ── Stack #4: nginx_uwsgi (TC-B.uws.*)

### TC-B.uws.001 — 스택 정상 기동

**Run:**
```bash
source script/test/helpers.sh
stack_up uws
docker compose -f $(stack_meta uws dir)/docker-compose.yml ps --format json | jq -r '.[] | .Name + " " + .State'
```

**Pass-if:** `nginx-uwsgi-webserver running`, `uwsgi-app running` 두 줄.

---

### TC-B.uws.002 — uv no-venv 정책 (★ Critical)

| Critical | Yes |

**Run:**
```bash
source script/test/helpers.sh
assert_no_venv uwsgi-app /www/django_sample
assert_system_python_import uwsgi-app django
```

**Pass-if:** 모두 exit 0.

---

### TC-B.uws.003 — working_dir 통일 (= /www/django_sample)

**Run:**
```bash
docker exec uwsgi-app pwd
```

**Pass-if:** 출력이 정확히 `/www/django_sample` (이전 `/application` 회귀 차단).

---

### TC-B.uws.004 — py-autoreload=0 (★ prod 안전, Critical 후보)

| Critical | Yes |

**Run:**
```bash
docker exec uwsgi-app grep -E '^py-autoreload\s*=' /application/uwsgi.ini
```

**Pass-if:** 출력이 `py-autoreload = 0` 또는 `py-autoreload=0`.

---

### TC-B.uws.005 — processes=8, threads=4

**Run:**
```bash
docker exec uwsgi-app grep -E '^(processes|threads)\s*=' /application/uwsgi.ini
```

**Pass-if:** `processes = 8` AND `threads = 4` 두 라인 모두 출력.

---

### TC-B.uws.006 — harakiri + reload-on-rss 설정

**Run:**
```bash
docker exec uwsgi-app grep -E '^(harakiri|reload-on-rss)\s*=' /application/uwsgi.ini
```

**Pass-if:** `harakiri = 60` AND `reload-on-rss = 800` 둘 다 출력.

---

### TC-B.uws.007 — 로그 분리 검증

**Run:**
```bash
sleep 5
docker exec uwsgi-app ls /log/uwsgi/ | grep -E "django_sample-(uwsgi|daemonize-uwsgi|uwsgi_access)\.log"
```

**Pass-if:** 3개 파일 모두 출력.

---

### TC-B.uws.008 — 스택 정리

**Run:** `source script/test/helpers.sh; stack_down uws`

---

## ── Stack #5: nginx_php (TC-B.php.*)

### TC-B.php.001 — 스택 정상 기동

**Run:**
```bash
source script/test/helpers.sh
stack_up php
docker compose -f $(stack_meta php dir)/docker-compose.yml ps --format json | jq -r '.[] | .Name + " " + .State'
```

**Pass-if:** `nginx-php-webserver running`, `php-app running` 두 줄.

---

### TC-B.php.002 — PHP-FPM 풀 워커 수 (start_servers=8)

**Run:**
```bash
n=$(docker exec php-app bash -c "ps -eo cmd | grep -c '^php-fpm: pool'")
echo "fpm pool workers: $n"
```

**Pass-if:** `n` ∈ `[6, 10]` (start_servers=8, idle timeout 으로 ±2 변동 허용).

---

### TC-B.php.003 — 로그 생성

**Run:**
```bash
sleep 3
ls log/php-fpm/
```

**Pass-if:** `access.log` 또는 `www-error.log` 중 하나 이상 존재.

---

### TC-B.php.004 — 스택 정리

**Run:** `source script/test/helpers.sh; stack_down php`

---

# Phase C — Temporal Tests (cron / reload / logrotate)

> 본 Phase 는 `nginx_gunicorn` 스택을 컨테이너 호스트로 사용한다. 시작 전 자동 기동.
>
> **letsencrypt.sh / certbot / openssl dhparam 관련 TC 는 모두 제외됨** — 실 도메인 의존 외부 검증 항목으로 분리. 자세한 내용은 [부록 D](#부록-d--자체-실행-불가능--외부-의존-항목).

## TC-C.bootstrap — nginx_gunicorn 기동 (Phase C 공통 선행)

| Type | AI EXEC | Critical | No |
|---|---|---|---|
| Preconditions | TC-A.001, TC-A.003 PASS |
| Cleanup | TC-Z.001 에서 일괄 정리 |

**Run:**
```bash
source script/test/helpers.sh
stack_up gun
```

**Pass-if:** `gunicorn-app` 컨테이너 running.

---

## TC-C.cron.001 — cron 데몬 실행 중

**Run:**
```bash
docker exec nginx-gunicorn-webserver bash -c "pgrep -a cron"
```

**Pass-if:** exit 0 AND `cron` 프로세스 1개 이상 출력.

---

## TC-C.cron.002 — cron 2분 간격 임시 변경 + 실제 발사 검증 (★ 시간 단축 테크닉)

| Type | AI EXEC | Critical | No |
|---|---|---|---|
| Duration | 약 4-5분 (cron 2회 발사 보장 대기) |
| Cleanup | self — 원본 crontab 자동 원복 |

**Note:** payload 는 letsencrypt 와 무관한 `nginx -t` 로 사용 — cron 발사 메커니즘만 검증한다.

**Run:**
```bash
CONT=nginx-gunicorn-webserver

# 1) 원본 백업
docker exec $CONT crontab -l > /tmp/cron-orig.txt
echo "=== ORIGINAL ==="; cat /tmp/cron-orig.txt

# 2) 2분 간격 시험 cron 주입 (payload = nginx -t)
docker exec $CONT bash -c 'echo "*/2 * * * * (echo \"FIRED at \$(date -Iseconds)\"; nginx -t) >> /log/nginx/crontab_test.log 2>&1" | crontab -'

# 3) 4분 대기 (2회 발사 보장)
echo "Waiting 240s for cron to fire twice..."; sleep 240

# 4) 발사 횟수 확인
docker exec $CONT bash -c "test -f /log/nginx/crontab_test.log && wc -l /log/nginx/crontab_test.log"
fires=$(docker exec $CONT bash -c "grep -c '^FIRED at' /log/nginx/crontab_test.log" 2>/dev/null || echo 0)
echo "Detected cron fires: $fires"

# 5) 원본 원복
docker cp /tmp/cron-orig.txt $CONT:/tmp/cron-orig.txt
docker exec $CONT bash -c "crontab /tmp/cron-orig.txt && rm /tmp/cron-orig.txt"
docker exec $CONT bash -c "rm -f /log/nginx/crontab_test.log"
rm -f /tmp/cron-orig.txt
echo "=== RESTORED ==="; docker exec $CONT crontab -l
```

**Pass-if:**
- `Detected cron fires` 값이 `>= 2` (최소 2회 발사)
- 마지막 `=== RESTORED ===` 블록의 cron 이 원본과 동일 (운영 cron 라인들 보존)

---

## TC-C.rel.001 — `nginx -s reload` 가 master PID 보존 (★ graceful reload)

| Critical | Yes |
|---|---|

**Run:**
```bash
CONT=nginx-gunicorn-webserver
PID_BEFORE=$(docker exec $CONT cat /var/run/nginx.pid)
docker exec $CONT bash -c "nginx -t && nginx -s reload"
sleep 2
PID_AFTER=$(docker exec $CONT cat /var/run/nginx.pid)
echo "PID_BEFORE=$PID_BEFORE PID_AFTER=$PID_AFTER"
test "$PID_BEFORE" = "$PID_AFTER" && echo "MASTER_PID_PRESERVED"
```

**Pass-if:** `MASTER_PID_PRESERVED` 라인 출력.

---

## TC-C.rel.002 — reload 중 HTTP 다운타임 = 0

**Run:**
```bash
CONT=nginx-gunicorn-webserver
# 백그라운드 reload 트리거
( sleep 1; docker exec $CONT nginx -s reload ) &
# 1초 간격 5회 호출
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost/
  sleep 1
done
wait
```

**Pass-if:** 5번의 HTTP code 응답 중 `502|503|504` 없음 (전부 동일한 정상 코드).

---

> **NOTE — letsencrypt.sh / certbot 관련 TC 제외**  
> 인증서 발급/갱신은 공인 DNS + 80포트 외부 도달이 필수이며 WSL 단독 환경에서 의미 있는 자체 검증이 불가능하다. `letsencrypt.sh`, `certbot --dry-run`, openssl dhparam 등 모든 letsencrypt/SSL 관련 TC 는 본 계획서에서 제외되었다. [부록 D](#부록-d--자체-실행-불가능--외부-의존-항목) 참조 — 운영자가 실 도메인 환경에서 별도 수동 검증.

---

## TC-C.lr.001 — logrotate 강제 트리거 → `.1` 생성 + 원본 truncate

**Run:**
```bash
SVC=gunicorn-app
docker exec $SVC bash -c "head -c 1M /dev/urandom | base64 > /log/gunicorn/gunicorn_access.log"
BEFORE_SIZE=$(docker exec $SVC stat -c %s /log/gunicorn/gunicorn_access.log)
docker exec $SVC logrotate -fv /etc/logrotate.d/gunicorn 2>&1 | tail -3
AFTER_SIZE=$(docker exec $SVC stat -c %s /log/gunicorn/gunicorn_access.log)
docker exec $SVC ls -la /log/gunicorn/ | grep gunicorn_access
echo "BEFORE=$BEFORE_SIZE AFTER=$AFTER_SIZE"
```

**Pass-if:**
- `AFTER_SIZE` < `BEFORE_SIZE` (copytruncate 효과)
- `ls` 출력에 `gunicorn_access.log.1` (또는 `.1.gz`) 존재

---

## TC-C.lr.002 — 2회 트리거 시 `.gz` 압축 (delaycompress 정상)

**Run:**
```bash
SVC=gunicorn-app
docker exec $SVC bash -c "head -c 1M /dev/urandom | base64 > /log/gunicorn/gunicorn_access.log"
docker exec $SVC logrotate -fv /etc/logrotate.d/gunicorn >/dev/null 2>&1
docker exec $SVC bash -c "head -c 1M /dev/urandom | base64 > /log/gunicorn/gunicorn_access.log"
docker exec $SVC logrotate -fv /etc/logrotate.d/gunicorn >/dev/null 2>&1
docker exec $SVC ls /log/gunicorn/ | grep -E "gunicorn_access\.log\.[0-9]+\.gz"
```

**Pass-if:** `*.log.[0-9]+.gz` 패턴 매칭 파일 1개 이상.

---

## TC-C.lr.003 — 로테이션 결과 정리 (회복)

**Run:**
```bash
SVC=gunicorn-app
docker exec $SVC bash -c "rm -f /log/gunicorn/gunicorn_access.log.* && truncate -s 0 /log/gunicorn/gunicorn_access.log"
docker exec $SVC ls /log/gunicorn/
```

**Pass-if:** `gunicorn_access.log` 단일 파일만 남음 (`.1`, `.gz` 부재).

---

# Phase U — uv 워크플로우

> 본 Phase 는 `nginx_gunicorn` 스택 가동 중 전제 (Phase C 후 연속 실행 또는 TC-C.bootstrap 선행).

## TC-U.host.001 — 호스트 측 uv sync 는 .venv 정상 생성 (대조군)

| Type | OPTIONAL — 호스트에 uv 설치 시만 실행 |

**Run:**
```bash
which uv || { echo "SKIP: host uv not installed"; exit 77; }
cd www/django_sample
uv sync --extra gunicorn --extra celery 2>&1 | tail -5
test -d .venv && echo "HOST_VENV_OK"
rm -rf .venv
cd ../..
```

**Pass-if:** `HOST_VENV_OK` 출력 (또는 `SKIP` 시 SKIP 처리).

---

## TC-U.add.001 — `uv add` → 컨테이너 재기동 → 새 의존성 시스템 Python 에 설치 확인

| Cleanup | self — pyproject.toml + uv.lock 원본 복원 |

**Run:**
```bash
# 백업
cp www/django_sample/pyproject.toml /tmp/pyproject.bak
[ -f www/django_sample/uv.lock ] && cp www/django_sample/uv.lock /tmp/uv.lock.bak

# 새 deps 추가 (호스트 uv 가 있어야 함; 없으면 직접 편집)
if which uv >/dev/null 2>&1; then
  (cd www/django_sample && uv add django-extensions)
else
  # uv 미설치 시 직접 편집 (sed)
  sed -i 's/^dependencies = \[/dependencies = [\n    "django-extensions",/' www/django_sample/pyproject.toml
fi

# 컨테이너 재기동 → uv sync 자동 실행
(cd compose/web_service/nginx_gunicorn && docker compose stop gunicorn-app && docker compose up -d gunicorn-app)
sleep 60   # uv sync + readiness

# 검증
docker exec gunicorn-app python -c "import django_extensions; print('IMPORT_OK')"
docker exec gunicorn-app test ! -d /www/django_sample/.venv && echo "STILL_NO_VENV"

# 원복
cp /tmp/pyproject.bak www/django_sample/pyproject.toml
[ -f /tmp/uv.lock.bak ] && cp /tmp/uv.lock.bak www/django_sample/uv.lock || true
rm -f /tmp/pyproject.bak /tmp/uv.lock.bak
(cd compose/web_service/nginx_gunicorn && docker compose stop gunicorn-app && docker compose up -d gunicorn-app)
sleep 30
```

**Pass-if:** `IMPORT_OK` AND `STILL_NO_VENV` 두 라인 모두 출력.

---

## TC-U.add.002 — 원복 후 django-extensions 가 시스템 Python 에서 제거되었는지

**Run:**
```bash
sleep 10
docker exec gunicorn-app python -c "import django_extensions" 2>&1 | grep -E "ModuleNotFoundError|No module"
```

**Pass-if:** `ModuleNotFoundError` 또는 `No module` 출력 (모듈 제거 확인).

---

# Phase R — Regression (스택 기동 불필요)

## TC-R.001 — `gunicorn-uvicorn-app` 잘못된 depends_on 참조 부재

**Run:** `grep -c "gunicorn-uvicorn-app" compose/web_service/nginx_uvicorn/docker-compose.yml`
**Pass-if:** 출력 = `0`.

## TC-R.002 — `service nginx restart/reload` 회귀 차단

**Run:**
```bash
out=$(grep -rnE 'service[[:space:]]+nginx[[:space:]]+(restart|reload)' \
    docker/ script/ compose/ --exclude-dir=test 2>/dev/null \
    | grep -vE ':[0-9]+:[[:space:]]*#')
[ -z "$out" ] && echo NONE || echo "$out"
```
**Pass-if:** 출력 = `NONE` (활성 코드에 없음 — 주석 라인과 `script/test/` 자체 제외).

## TC-R.003 — `poetry install` 회귀 차단

**Run:** `grep -rE 'poetry\s+(install|config)' compose/ www/django_sample/pyproject.toml || echo NONE`
**Pass-if:** 출력 = `NONE`.

## TC-R.004 — `latest` / `master` 태그 회귀 (insready/redis-stat 제외)

**Run:** `grep -rE 'image:.*:(latest|master)' compose/web_service/ | grep -v 'insready' || echo NONE`
**Pass-if:** 출력 = `NONE`.

## TC-R.005 — `loglotate` 오타 회귀

**Run:**
```bash
out=$(grep -r "loglotate" . \
    --include="*.yml" --include="*.sh" --include="*.md" \
    --exclude-dir=test --exclude=TEST-PLAN.md 2>/dev/null)
[ -z "$out" ] && echo NONE || echo "$out"
```
**Pass-if:** 출력 = `NONE` (테스트 인프라 자기 매칭 제외).

## TC-R.006 — `py-autoreload = 1` 회귀 (prod 안전)

**Run:** `grep -E '^py-autoreload\s*=\s*1' config/app-server/uwsgi/uwsgi.ini || echo NONE`
**Pass-if:** 출력 = `NONE`.

## TC-R.007 — compose 활성 명령에 `uv run` 잔존 차단

**Run:** `grep -rE '^\s*command:.*uv run' compose/ || echo NONE`
**Pass-if:** 출력 = `NONE`.

## TC-R.008 — pyproject.toml 이 PEP 621 (poetry 제거 확인)

**Run:**
```bash
grep -q '^\[project\]' www/django_sample/pyproject.toml && echo PEP621_OK
grep -q '^\[tool.poetry\]' www/django_sample/pyproject.toml && echo "POETRY_STILL_PRESENT" || echo POETRY_CLEAR
```

**Pass-if:** `PEP621_OK` AND `POETRY_CLEAR` 두 줄 모두 출력.

---

# Phase L — Load (옵션)

## TC-L.001 — wrk 30초 부하 (gunicorn 스택)

| Type | OPTIONAL — wrk 설치 시만 실행 |
| Critical | No |
| Preconditions | nginx_gunicorn 가동 중 |

**Run:**
```bash
which wrk || { echo "SKIP: wrk not installed"; exit 77; }
wrk -t8 -c100 -d30s http://localhost/ 2>&1 | tee /tmp/wrk-gunicorn.log
err=$(grep -oE 'Socket errors:.*$' /tmp/wrk-gunicorn.log || echo "0")
echo "Errors: $err"
```

**Pass-if:** `Socket errors: connect 0, read 0, write 0, timeout 0` (모두 0) 또는 errors 라인 부재 (= 0).

---

## TC-L.002 — 메모리 누수 자동 점검 (부하 전후 RSS ratio ≤ 1.2)

**Run:**
```bash
which wrk >/dev/null || { echo "SKIP: wrk not installed"; exit 77; }

# MemUsage 형식 "150MiB" / "1.2GiB" 등을 MB 로 정규화
to_mb() {
    local v=$1
    local num=$(echo "$v" | sed -E 's/([0-9.]+).*/\1/')
    local unit=$(echo "$v" | sed -E 's/[0-9.]+//')
    case "$unit" in
        GiB|GB) awk -v n="$num" 'BEGIN { print n * 1024 }' ;;
        MiB|MB) echo "$num" ;;
        KiB|kB) awk -v n="$num" 'BEGIN { print n / 1024 }' ;;
        *)      echo "$num" ;;
    esac
}

raw_before=$(docker stats --no-stream --format "{{.MemUsage}}" gunicorn-app | awk -F'/' '{print $1}' | tr -d ' ')
wrk -t4 -c50 -d60s http://localhost/ >/dev/null 2>&1
sleep 5
raw_after=$(docker stats --no-stream --format "{{.MemUsage}}" gunicorn-app | awk -F'/' '{print $1}' | tr -d ' ')

mb_before=$(to_mb "$raw_before")
mb_after=$(to_mb "$raw_after")
ratio=$(awk -v a="$mb_after" -v b="$mb_before" 'BEGIN { print (b > 0) ? a / b : 0 }')
echo "BEFORE=${mb_before}MB AFTER=${mb_after}MB ratio=$ratio"
awk -v r="$ratio" 'BEGIN { exit (r <= 1.2) ? 0 : 1 }'
```

**Pass-if:** exit 0 (`ratio <= 1.2` AND wrk 정상 설치).

---

# Phase Z — Cleanup

## TC-Z.001 — 모든 스택 down

**Run:**
```bash
for s in gun uvi dap uws php; do
  source script/test/helpers.sh
  stack_down "$s" 2>/dev/null || true
done
docker ps --filter "name=nginx-" --filter "name=-app" -q | wc -l
```

**Pass-if:** `wc -l` 출력 = `0`.

---

## TC-Z.002 — 테스트 이미지 제거

**Run:**
```bash
docker image rm devspoon/gunicorn:test devspoon/uwsgi:test devspoon/nginx:test devspoon/php-fpm:test 2>/dev/null || true
docker images devspoon/* -q | wc -l
```

**Pass-if:** `wc -l` 출력 = `0`.

---

## TC-Z.003 — 호스트 `.venv` 잔존 점검

**Run:** `find www/ -type d -name ".venv" 2>/dev/null || echo NONE`
**Pass-if:** 출력 = `NONE` (호스트에 venv 가 남아있지 않음).

---

## TC-Z.004 — 임시 로그 정리

**Run:**
```bash
rm -f /tmp/cron-orig.txt /tmp/pyproject.bak /tmp/uv.lock.bak /tmp/wrk-*.log
echo "DONE"
```

**Pass-if:** `DONE` 출력 (idempotent).

---

# 부록 A — Critical FAIL 정의

| TC ID | 항목 | 실패 시 의미 |
|---|---|---|
| TC-P.001 | Preflight | 환경 자체가 부적합 → 모든 후속 TC SKIP |
| TC-A.008 | UV_PROJECT_ENVIRONMENT ENV | no-venv 정책의 근간이 무너짐 |
| TC-A.010 | nginx + certbot + crontab 등록 | nginx 컨테이너 자체가 사양 미충족 |
| TC-B.gun.002 / TC-B.uvi.002 / TC-B.dap.002 / TC-B.uws.002 | uv no-venv 정책 (4개 스택) | 컨테이너 안에 .venv 가 생긴다면 설계 의도 위배 |
| TC-B.uws.004 | py-autoreload=0 | 프로덕션에서 hot-reload 가 작동 → 불안정 |
| TC-C.rel.001 | nginx -s reload graceful | 운영 시 다운타임 |
| `TEST_FAIL_FAST=critical` (기본) 일 때 위 TC 중 하나라도 FAIL → 즉시 중단 + 결과 보고 |

---

# 부록 B — 결과 보고 (자동 생성)

각 TC 실행 시 `record_result` 함수가 `/tmp/devspoon-test-results.tsv` 에 다음 형식으로 누적:

```
TC_ID                PHASE    STACK   STATUS  DURATION  TIMESTAMP            NOTES
TC-A.001             A        -       PASS    312s      2026-05-14T15:30:01Z
TC-B.gun.001         B        gun     PASS    35s       2026-05-14T15:35:14Z
TC-B.gun.002         B        gun     PASS    3s        2026-05-14T15:35:50Z
...
```

테스트 종료 후 요약은 다음 명령으로:

```bash
source script/test/helpers.sh; print_summary
```

출력 예:
```
=== Test Summary ===
Total: 64  PASS: 62  FAIL: 1  SKIP: 1

Failed cases:
  - TC-C.cron.002  cron fires only 1 in 4 min (expected >=2)
```

---

# 부록 D — 자체 실행 불가능 / 외부 의존 항목

본 계획서의 모든 AI EXEC TC 는 WSL 단독 환경(인터넷 가용 가정)에서 자체 실행 가능하도록 설계되었다. 그러나 다음 항목들은 **실제 운영 환경 (도메인 + 공인 DNS) 에서만 의미 있는 검증**이며, 본 계획서 범위 밖이다. 운영자가 별도로 수동 검증해야 한다.

| 항목 | 이유 | 운영자 수동 검증 방법 |
|---|---|---|
| **letsencrypt 실 인증서 발급** | 공인 DNS A 레코드 + 80 포트 외부 도달 필수 | 실 도메인 환경에서 `script/letsencrypt.sh` 실행 → `/etc/letsencrypt/live/<domain>/` 생성 확인 |
| **certbot renew 실 갱신** | 발급된 인증서 만료일 30일 미만 시점에서만 실제 갱신 | `certbot renew` 실제 호출 후 새 인증서 NotAfter 비교 |
| **gunicorn/uvicorn/daphne upstream HTTP 실응답** | 도메인 server 블록 + `proxy_pass` 활성화 필요 (default.conf 의 444 catch-all 회피) | 실 도메인 conf 배치 후 `curl https://<domain>/` |
| **WebSocket 실 핸드셰이크 (daphne)** | 실 도메인 + ALPN/TLS 협상 필요 | `wscat -c wss://<domain>/ws/` |
| **HTTPS SSL/TLS 응답** | 실 인증서 필요 | `curl -v https://<domain>/` (Server Hello, cert chain) |
| **외부 IP rate-limit 동작 (ngxblocker `flood`/`addr`)** | 단일 IP 90r/s 초과 트래픽 생성 필요 (자체 환경에서도 wrk 로 가능하지만 WSL→localhost 는 의미 한정) | 실 트래픽 환경 또는 vegeta/k6 부하 후 nginx error.log 의 `limiting requests` 라인 확인 |
| **5개 스택 동시 가동** | 모두 80/443 포트 점유 → 호스트당 1스택만 가능 | 별도 호스트 / 별도 포트 매핑으로 운영 |

## 자체 실행 가능하지만 인터넷 필수인 항목 (참고)

다음은 외부 도메인이 아닌 외부 **서비스** 의존 — 인터넷 가용 시 자체 실행 OK:

| 항목 | 외부 의존처 |
|---|---|
| Phase A 이미지 빌드 | apt repo / PyPI / Python source / Percona repo |
| ngxblocker `update-ngxblocker` 갱신 검증 (별도 verify-ngxblocker.sh) | raw.githubusercontent.com |
| TC-U.add.001 (uv add django-extensions) | PyPI |

> letsencrypt/certbot 관련 항목 (TC-C.le.\*) 은 본 계획서에서 전부 제거됨. 운영자가 실 도메인 환경에서 별도 수동 검증할 항목으로, 위 표 첫 행 ("letsencrypt 실 인증서 발급" 등) 만 적용된다.

---

# 부록 C — 트러블슈팅 빠른 진단

| 증상 | 진단 명령 | 가능한 원인 |
|---|---|---|
| `502 Bad Gateway` | `docker compose logs <app>` | upstream 미기동, uv sync 미완료, 포트 미스매치 |
| 호스트 `.venv` 생성됨 | `docker exec <c> env \| grep UV_PROJECT_ENVIRONMENT` | Dockerfile ENV 누락 (회귀) |
| 컨테이너 시작 후 즉시 종료 | `docker compose logs --tail=50 <app>` | uv sync 실패, pyproject.toml 오류 |
| `wait_for_ready` 타임아웃 | `docker logs <container> 2>&1 \| tail -100` | readiness pattern 미스매치 또는 진짜 기동 실패 |
| logrotate 미동작 | `docker exec <c> ls /etc/logrotate.d/` | 마운트 경로 오타, cron 미실행 |
| certbot dry-run 실패 | `docker exec <c> certbot renew --dry-run 2>&1` | 인증서 미존재 시 정상 메시지 출력 |
| cron 안 fire | `docker exec <c> pgrep -a cron` | cron 데몬 미기동 (entrypoint 확인) |

---

# 부록 D — 사용자 요청 예시 (실제 지시 양식)

```
"preflight 해줘"
→ AI: TC-P.001 실행 후 결과 보고

"Phase A 전체 — REUSE_BUILDS=1"
→ AI: TC-A.001~010 캐시 활용 모드로 실행

"gunicorn 스택 테스트"
→ AI: TC-B.gun.001~007 순차 실행, 마지막에 stack_down

"TC-B.uvi.002 만 실행해줘"
→ AI: Preconditions(TC-A.001/003 PASS, uvicorn 스택 up) 확인 후
       부족하면 의존 TC 선행 → TC-B.uvi.002 실행

"회귀만 빠르게"
→ AI: TC-R.001~008 순차 실행 (스택 기동 없음, 약 1분)

"Critical FAIL 만 빠르게"
→ AI: Critical=Yes 인 TC 만 추출 실행
   (TC-P.001, A.008, A.010, B.*.002, B.uws.004, C.rel.001)

"전체 실행 — TEST_FAIL_FAST=always"
→ AI: P → A → B(5스택) → C → U → R → L(skip) → Z
       첫 FAIL 즉시 중단
```
