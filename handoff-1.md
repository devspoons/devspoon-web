# devspoon-web Session Handoff #1

> **이전 세션 종료 시점**: 2026-05-14
> **작업 디렉터리**: `c:/Users/rnd15/Documents/project/github/devspoon/devspoon-web`
> **WSL Docker**: 가용 (29.4.1, WSL2 Ubuntu)
> **목적**: 새 세션에서 이어서 작업할 수 있도록 현재 상태/결정/대기 항목 정리

---

## 1. 이번 세션에서 완료된 작업 (요약)

### A. Dockerfile / Compose 정합성
- `ubuntu:latest` → **`ubuntu:24.04`** (gunicorn, uwsgi)
- `nginx:latest` → **`nginx:1.27-bookworm`**
- `redis:latest` → **`redis:7.4-alpine`** (5개 compose)
- `mher/flower:master` → **`mher/flower:2.0.1`** (4개)
- nginx reload: **`service nginx restart` 금지**, **`nginx -s reload`** 패턴 통일
- letsencrypt.sh 의 중복 cron 라인 제거
- `nginx_uvicorn` 의 `depends_on: gunicorn-uvicorn-app` (존재 X) → `uvicorn-app` 수정
- uwsgi compose `working_dir`: `/application` → `/www/${PROJECT_DIR}`
- Dockerfile 레이어 통합 (26 → 4 RUN), Python 3.14 source compile, `--enable-optimizations` 제거 (PGO race 회피)

### B. 8 core / 8 GB / 수동 stop 배포 정책 적용
- gunicorn: workers=9, threads=4, preload_app=True, max_requests=2000
- uvicorn: workers=8 (1/core), UvicornWorker, preload_app=True, timeout=30
- uwsgi: processes=8, threads=4, **`py-autoreload=0`** (prod 안전), harakiri=60, reload-on-rss=800MB
- php-fpm: pm.max_children=40, start=8, min/max_spare=8/24
- celery: `--concurrency=8 --max-tasks-per-child=2000`

### C. 로그 표준화 + logrotate 오타 수정
- 모든 로그 `/log/<service>/[<sub>/]*.log` 식별 가능 구조
- **`script/loglotate/` → `script/logrotate/`** rename (compose 마운트 경로와 정합)
- `.gitkeep` 11개로 git 추적 유지

### D. django_sample uv 전환 (poetry → PEP 621)
- `pyproject.toml`: `[project]`, `[project.optional-dependencies]` (gunicorn/uvicorn/daphne/uwsgi/celery), `[tool.uv] package = false`
- **`requirements.txt` 는 사용자 요청대로 원본 보존** (외부 도구 호환)
- **Django 4.0.6 → `Django>=5.1,<5.3`** (Python 3.14 `cgi` 모듈 부재 대응; PEP 594)
- 4개 compose `command:` → `uv sync --inexact --extra <variant> --extra celery && exec <binary>`

### E. uv "no-venv" 컨테이너 정책 (★ 중요)
- Dockerfile ENV: **`UV_PROJECT_ENVIRONMENT=/usr/local`**, `UV_LINK_MODE=copy`, `UV_COMPILE_BYTECODE=1`, `UV_NO_CACHE=1`
- **`UV_PYTHON=/usr/local/bin/python3.14`** + `UV_PYTHON_PREFERENCE=only-system` (시스템 python3.12 회피)
- 컨테이너 안에 `.venv` 미생성 — 시스템 Python 사이트패키지에 직접 설치
- 호스트 개발에서는 정상적으로 `.venv` 생성 (UV_PROJECT_ENVIRONMENT 미설정)
- compose 명령에서 `uv run` 제거 — 시스템 바이너리 직접 호출
- `--inexact` 플래그로 Dockerfile 사전 설치 패키지 보존

### F-bis. sample_nginx*.conf 의 ngxblocker include 축소 (★ 세션 말미 사용자 정련)

세션 종료 직전 사용자가 6개 sample_nginx{,_https}.conf 모두에서 **server 컨텍스트의 ngxblocker include 를 2개로 축소**:

```nginx
# server 블록 안 — 이 2개만!
include /etc/nginx/bots.d/blockbots.conf;     # server-level `if ($bad_bot)` + 444 return
include /etc/nginx/bots.d/ddos.conf;           # server-level limit_* (봇만 적용)
```

이전 9-line include (blacklist-*, whitelist-*, bad-referrer-words.conf, custom-bad-referrers.conf 등 7개 추가) 는 **제거**. 그 파일들은 `globalblacklist.conf` 가 http 컨텍스트의 map/geo 블록에서 자동으로 include 하므로 server 블록에 직접 두면 운영자 항목 추가 시 `nginx -t` 실패한다는 게 사용자 의도.

→ **새 세션 검증 필요 (§5의 0번 확장)**: 2개 include 만으로 정상 UA 200 / 봇 UA 444 유지되는지, `nginx -t` 통과하는지 재확인.

### F. ngxblocker 마이그레이션 (★ 신규)
- 정적 `config/web-server/nginx/{gunicorn,php,uwsgi}/conf.d/bad_bot.conf` **3개 모두 삭제** (백업: `script/backup/20260514/bad_bot/` ← 검증 통과 후 후속 세션에서 제거, 필요 시 git history 에서 `git show <DELETE_COMMIT>^:.../bad_bot.conf` 로 복원)
- `docker/nginx/Dockerfile`:
  - install/setup/update-ngxblocker 다운로드 + `install-ngxblocker -x -c /etc/nginx`
  - **`-c /etc/nginx`** 핵심 — compose 가 `conf.d/` 를 host mount 하므로 그 밖에 위치시켜야 `globalblacklist.conf` 가 가려지지 않음
  - 6시간 cron: `update-ngxblocker -c /etc/nginx && nginx -t && nginx -s reload`
  - `blacklist-domains.conf` 빈 파일 touch (install 이 안 만드는 파일)
  - 최종 `update-ca-certificates` 재실행 (apt-get clean 후 ca-certificates.crt 소실 방지)
- 3개 nginx.conf 의 http 블록에 **`include /etc/nginx/globalblacklist.conf;`** 추가
- 6개 sample_nginx*.conf 의 `if ($bad_bot) { return 403; }` → 9-line ngxblocker `include /etc/nginx/bots.d/*.conf;`
- README §3.5 "악성 봇 / DDoS 차단" 섹션 신설 + Appendix D

### G. rate-limit 정책 정리 (★ 중요, 세션 말미에 사용자가 추가 정련)
- **프로젝트 측 `limit_req` / `limit_conn` 호출은 sample 에서 주석 처리** (정상 트래픽 무영향)
- **(세션 종료 직전 갱신)** 3개 nginx.conf (gunicorn/uwsgi/php) 모두 **`limit_conn_zone` / `limit_req_zone` 정의 자체를 제거** — rate-limit 일체를 ngxblocker 에 위임:
  - `globalblacklist.conf` 가 `bot1_connlimit`~`bot4_connlimit` + `bot1_reqlimitip`~`bot4_reqlimitip` zone 정의
  - + 봇 매칭 시에만 IP 로 채워지는 key 변수 `$bot1_iplimit`~`$bot4_iplimit` 정의
  - `bots.d/ddos.conf` 가 이 zone 들을 server 블록에서 호출
  - **정상 트래픽 시 key 가 빈 문자열 → nginx 가 자동 제외 → 정상 사용자 무영향**
- nginx.conf 에 `map_hash_max_size 4096; map_hash_bucket_size 256;` 추가 (ngxblocker 의 1000+ regex map 대응)
- **새 세션에서 검증 필요**: 이 정책 변경 후 `verify-ngxblocker.sh` 재실행하여 ddos.conf 가 실제로 bot* zone 만 사용하는지 / `addr`/`flood` zero-size 에러 재발하지 않는지 확인 ([§5 우선순위 0번](#5-다음-세션에서-가장-먼저-할-일-후보-우선순위-순) 참조)

> **★ 2026-05-14 후속 검증 — §G 정정 (handoff-1.md 후속 세션)**
>
> §G 의 "globalblacklist.conf 가 bot1~bot4 zone 8개 + `$bot1_iplimit`~`$bot4_iplimit` 변수를 정의한다" **주장은 거짓**으로 확인됨. 실제 ngxblocker 업스트림:
> - `globalblacklist.conf` 는 **`bot2_*` + `bot4_*` 4 zone 만** 정의 (line 19272-19279)
> - 변수는 **`$bot_iplimit`** + **`$bot_iplimit2`** 두 개 (line 19248, 19259 의 `map $bad_bot ...`)
> - **`bots.d/ddos.conf` 는 변경 없이 여전히 `limit_conn addr 200;` + `limit_req zone=flood ...`** (= `addr`/`flood` zone 사용. bot* 사용 안 함)
>
> 따라서 §G 의 "nginx.conf 에서 zone 정의 제거" 정책은 운영 차단 결함이었고 (`zero-size shared memory zone "addr"` emerg 로 첫 도메인 활성화 시 nginx 기동 실패), 후속 세션에서 다음과 같이 정정:
>
> ```nginx
> # 3개 nginx.conf 의 http 블록 (gunicorn/uwsgi/php 모두 동일)
> limit_conn_zone $bot_iplimit zone=addr:50m;
> limit_req_zone  $bot_iplimit zone=flood:50m rate=90r/s;
> ```
>
> `$bot_iplimit` 키이므로 정상 사용자 무영향 유지 + ddos.conf 호환. `verify-ngxblocker.sh` ALL CHECKS PASSED 재확인 완료. 메모리 `project_nginx_rate_limit_policy.md` 도 이 정책으로 갱신됨.

### H. 테스트 인프라 구축
- **`TEST-PLAN.md`** (TC 카드 형식, AI 자체 실행 가능)
- `script/test/preflight.sh` — 환경/파일 검사 (30초)
- `script/test/helpers.sh` — wait_for_ready, assert_*, stack_meta, **pre_phase_cleanup**, record_result 등
- `script/test/verify-ngxblocker.sh` — ngxblocker 종단간 검증 (**ALL CHECKS PASSED**)
- TEST-PLAN.md 의 letsencrypt/certbot 관련 TC **전부 제거** (실 도메인 의존)
- 부록 D — 자체 실행 불가능/외부 의존 항목 명시
- 호스트 catch-all 444 문제 해결을 위해 **임시 server 블록 (blocker.test)** 패턴 채택

---

## 2. 현재 검증 통과 상태

| 영역 | 상태 | 비고 |
|---|---|---|
| Preflight (32 checks) | ✅ PASS | docker/jq/compose 등 환경 |
| 회귀 R.001~008 | ✅ 8/8 PASS | poetry/loglotate/service nginx restart 등 회귀 차단 |
| Phase A 이미지 빌드 (gunicorn/uwsgi/nginx/php-fpm) | ✅ 빌드 성공 | TC-A.005~010 모두 PASS |
| ngxblocker 종단간 (`verify-ngxblocker.sh`) | ✅ **ALL CHECKS PASSED** | 정상 UA 200, 봇 UA 444, 7851 패턴, cron 등록, update-ngxblocker 실 다운로드 |

### 미완료 검증
- **Phase B 의 uvicorn / daphne / uwsgi 스택** — gunicorn 만 종단간 검증됨. 나머지 3개는 TEST-PLAN.md 의 신 TC (TC-B.\*.003 임시 server 블록 패턴, .004 시작 로그 only) 로 재실행 필요
- **Phase L 부하 테스트** — wrk 미설치 시 SKIP (OPTIONAL)
- **TC-U.add.001** uv add → 컨테이너 재기동 검증

---

## 3. 핵심 정책 / 결정 (메모리 저장됨)

`.claude/projects/.../memory/` 에 저장된 영구 메모리:

### feedback_autonomous_execution.md
- 사용자 명시: "동일 오류로 3회 이상 다른 방법 시도해도 해결 안 되는 경우만 확인 요청"
- 매 단계 권한 요청 없이 자율 진행

### project_nginx_rate_limit_policy.md
- 프로젝트 측 `limit_req` / `limit_conn` 호출은 sample 에 주석으로만 보존
- 실제 쓰로틀링은 ngxblocker(`globalblacklist.conf` 의 `bot2_*` + `ddos.conf` 의 `addr`/`flood`) 가 봇 흐름에만 적용
- nginx.conf 에서 정의할 zone: **`addr`, `flood` 만** (storage 용도)
- `bot2_*`, `bot4_*` 직접 정의 금지 (globalblacklist.conf 가 정의)

### MEMORY.md (인덱스)
위 2개 메모리 참조 라인 포함

---

## 4. 주요 파일 변경 인덱스

```
docker/
  gunicorn/Dockerfile          UV ENV, Python 3.14, no PGO, entrypoint-with-cron
  uwsgi/Dockerfile             동일 + uv pip 추가
  nginx/Dockerfile             ngxblocker (-c /etc/nginx), 6h cron, CA cert 보강
  php-fpm/Dockerfile           변경 없음 (PHP 7.3 EOL — 별건)

compose/web_service/
  nginx_gunicorn/docker-compose.yml    uv sync --inexact, gunicorn extras
  nginx_uvicorn/docker-compose.yml     uvicorn extras, depends_on 버그 fix
  nginx_daphne/docker-compose.yml      daphne extras
  nginx_uwsgi/docker-compose.yml       uwsgi extras, working_dir 통일
  nginx_php/docker-compose.yml         이미지 핀만 (Python 무관)

config/
  app-server/gunicorn/gunicorn.conf.py     8c/8g 튜닝
  app-server/uvicorn/uvicorn.conf.py       신규 (gunicorn_uvicorn.conf.py 대체)
  app-server/uwsgi/uwsgi.ini               py-autoreload=0, harakiri, reload-on-rss
  app-server/php/pool.d/sample_php.conf    8c/8g 튜닝
  web-server/nginx/{gunicorn,uwsgi,php}/nginx_conf/nginx.conf
      → globalblacklist include, addr/flood zone, rate-limit 주석화
  web-server/nginx/{gunicorn,uwsgi,php}/sample_nginx*.conf  (6개)
      → if ($bad_bot) 제거, bots.d/* include 9개, limit_* 주석화
  web-server/nginx/{gunicorn,php,uwsgi}/conf.d/bad_bot.conf  ← 삭제 (백업 있음)

www/django_sample/
  pyproject.toml               PEP 621 uv, Django>=5.1, extras 5종
  requirements.txt             원본 그대로 유지 (사용자 요청)
  uv.lock                      자동 생성 (커밋 권장)

script/
  letsencrypt.sh               cron 중복 제거
  logrotate/ (rename from loglotate/)   compose 마운트 정합
  test/
    preflight.sh               환경 32-check (read-only, ~30초)
    helpers.sh                 공통 함수 라이브러리 (TEST-PLAN.md 가 source)
    verify-ngxblocker.sh       ngxblocker 종단간 검증 (PASS 검증됨)
    # 가이드 문서는 README.md §10 "테스트 / 검증 인프라" 로 통합됨
  # backup/20260514/bad_bot/   ← 검증 통과 후 제거됨. 복원 필요 시 git history 참조
  # test/run-{critical,step3-4,test-final}.sh  ← 일회성 자동화. 제거됨 (TEST-PLAN.md 가 직접 참조하지 않음)

TEST-PLAN.md                   TC 카드 형식, letsencrypt 제거, 부록 D 신설
README.md                      §3.5 ngxblocker, §8 uv no-venv, §9 변경 영향 매트릭스
.gitignore                     **/.venv/, __pycache__ 등 추가
handoff-1.md                   본 문서
```

---

## 5. 다음 세션에서 가장 먼저 할 일 후보 (우선순위 순)

0. ~~**★ 최신 nginx.conf 정책 재검증**~~ → **✅ 완료 (2026-05-14, 후속 세션)**. 결과: §G 의 신 정책이 운영 차단 결함이었고, `$bot_iplimit` 키로 `addr`(50m) + `flood`(50m rate=90r/s) zone 정의를 nginx.conf 에 복원. `verify-ngxblocker.sh` ALL CHECKS PASSED. 상세는 위 §G 의 정정 노트 참조.

1. **Phase B 잔여 스택 검증** — uvicorn / daphne / uwsgi 의 TC-B.\*.001~ 풀 실행. gunicorn 처럼 임시 server 블록 패턴으로 봇 차단까지 자체 검증.
2. **TC-U.add.001 검증** — uv add 후 컨테이너 재기동 → django-extensions 시스템 Python 로드 확인.
3. **Phase L (옵션)** — wrk 설치되어 있다면 부하 + 메모리 누수 자동 점검 (TC-L.002 새 산술 비교 로직).
4. **uv.lock 커밋 정책 확정** — 현재 .gitignore 에는 주석으로 "커밋 권장" 표기, 실제 커밋 여부 결정.
5. **PHP 7.3 EOL 대응** — 별건. PHP 8.3+ 마이그레이션은 추후.

---

## 6. 진행 중 / 미해결 이슈 (있을 시 메모)

- **5개 스택 동시 가동 불가** — 모두 80/443 점유. 단일 호스트당 1 스택 (부록 D 명시)
- **insready/redis-stat:latest** — 단일 태그(미유지 이미지)로 의미 없음. 추후 alternative (rediscommander/redis-commander) 교체 검토
- **첫 빌드 시간** — 인터넷 + 캐시 미스 환경에서 60-90 분 (Python source compile + percona). 캐시 활용 시 5분 이내.

---

## 7. 새 세션에서 사용할 명령

다음 한 줄 명령으로 새 세션에서 본 작업을 이어서 시작할 수 있다:

```
@handoff-1.md 를 읽고 이전 세션 상태를 파악한 후, MEMORY.md 의 사용자 피드백/정책 메모리도 함께 로드해줘. 그 다음 §5 의 우선순위 항목 중 무엇부터 진행할지 제안해줘.
```

또는 더 구체적으로 특정 작업을 지정:

```
@handoff-1.md 를 로드하고, §5 의 1번 항목 (Phase B 잔여 스택 검증) 부터 시작해줘.
TEST-PLAN.md 의 TC-B.uvi.* → TC-B.dap.* → TC-B.uws.* 순서대로 자율 실행, 결과는 /tmp/devspoon-test-results.tsv 에 누적.
```

작업 디렉터리 가정: `c:/Users/rnd15/Documents/project/github/devspoon/devspoon-web`
