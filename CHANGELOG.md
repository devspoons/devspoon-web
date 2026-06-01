# Changelog

본 프로젝트의 모든 주요 변경사항은 본 파일에 기록됩니다. 형식은 [Keep a Changelog](https://keepachangelog.com/) 기반, 버전 관리는 의미 있는 마일스톤별 섹션. 자세한 패치 이력과 의사결정 컨텍스트는 `docs/patch/` 시리즈에 별도 정리되어 있습니다.

## [Unreleased] — 2026-06-01-aisum-sync 브랜치

> **브랜치**: [`2026-06-01-aisum-sync`](https://github.com/devspoons/devspoon-web/tree/2026-06-01-aisum-sync) · **base**: `newflow` · **PR**: <https://github.com/devspoons/devspoon-web/pull/new/2026-06-01-aisum-sync>
>
> **상세 문서**: [`docs/patch/2026-06-01-PATCH-001-INDEX.md`](docs/patch/2026-06-01-PATCH-001-INDEX.md) 부터 시작하는 7 문서 시리즈

aisum-infrakit (사내 fork) 의 검증 산출물을 devspoon-web 으로 역머지한 **일괄 정합화 패치**. 33 atomic commits, 3 라운드 자율 audit 사이클을 거쳐 수렴. 사용자 원본 요청의 5 가지 HTTPS 검증 항목 (dhparam build/backup/restore + nginx https sample + 경로) 모두 PASS, 풀스택 5 스택 (gunicorn / PHP 7.3 / PHP 8.4 / uvicorn / daphne) HTTP 200 검증, 6 verify_\*.sh 회귀 검증 통과.

### Added — 신규 자산

- **`docs/patch/` 7 문서 시리즈** (1437 라인) — 본 패치의 self-contained 학습/재현 패키지
  - `2026-06-01-PATCH-001-INDEX.md` 마스터 인덱스 + 32 commits 라운드별 요약
  - `2026-06-01-PATCH-002-CONTEXT.md` 의사결정 컨텍스트, 보존 정책, 사용자 결정 3건
  - `2026-06-01-PATCH-003-IMPLEMENTATION.md` 8 영역 × (변경 파일·패턴·함정·commit) 매트릭스
  - `2026-06-01-PATCH-004-VERIFICATION.md` verify\_\*.sh + Exit Criteria 12 항목
  - `2026-06-01-PATCH-005-AUDIT-CYCLES.md` 3 라운드 audit history + false positive 학습
  - `2026-06-01-PATCH-006-RUNBOOK.md` Phase 0~9 단계별 재현 명령
  - `2026-06-01-PATCH-007-CLAUDE-PROMPT.md` Claude 학습 최적화 prompt 4종 (마스터/단축/cherry-pick/audit)
- **`config/web-server/nginx/uvicorn/` 신설** — 기존엔 `nginx_uvicorn` compose 스택만 있고 nginx conf 가 누락되어 dead code 였음. aisum 의 구조를 그대로 가져와 완성
- **`config/app-server/uvicorn/gunicorn_uvicorn.conf.py`** — gunicorn + UvicornWorker 패턴 (다수 워커 prefork ASGI)
- **`script/test_run/` 16 → 21 개 스크립트** — aisum-infrakit 의 회귀 검증 배터리 import:
  - `s0_prereq.sh`, `s1b_exit_check.sh`, `s1b_nginx_conf_generators.sh`, `s2_build.sh`, `s2a_image_inspect.sh`, `s3_stack_smoke.sh`, `s5_https.sh`, `s6_regression.sh` (단계화)
  - `ssl_diag.sh`, `verify_block.sh`, `celery_diag.sh`, `check_cgi.sh`, `check_cgi2.sh`, `check_excode.sh`, `inspect_orphans.sh`, `sim_exit.sh` (보조)
- **`script/test_run/verify_*.sh` 6 종** — 신규 검증 자산:
  - `verify_compose_yml.sh` 6 스택 docker-compose.yml + dhparam 마운트 + 안티패턴 부재
  - `verify_conf_generators.sh` 4 스택 × HTTP+HTTPS 생성기
  - `verify_dhparam_lifecycle.sh` A/B/C 3 단계 백업/복원 (PORT 랜덤화 + 폴링 강화)
  - `verify_dhparam_host_wins.sh` STEP-C 호스트 백업 우선
  - `verify_nginx_standalone.sh` 실제 컨테이너 기동 + 전체 마운트 (`docker cp` 로 종료 컨테이너에서도 dhparam 추출)
  - `verify_healthcheck.sh` 정적 12 PASS + 런타임 옵션
- **`script/test_run/verify_integration_{uvicorn,daphne,uwsgi}.sh` 3 종** — per-stack 풀스택 통합 verifier
- **`www/fastapi_sample/`, `www/flask_sample/`, `www/certbot/`** — 신규 샘플 앱 + ACME webroot 표준 위치
- **`docker/nginx/Dockerfile` 섹션 8·9** — `openssl dhparam` 빌드 시 굽기 + `/docker-entrypoint.d/20-dhparam.sh` 호스트 백업/복원 hook
- **6 스택 docker-compose.yml 의 healthcheck** — `bash /dev/tcp` probe + webserver `depends_on: service_healthy` 강화
- **README `§11 WSL2 운영 가이드`** — `/etc/wsl.conf` 권장, dhparam 권한, /mnt/c 성능, healthcheck timing 4 하위절
- **README `§0.5.9 aisum-infrakit 와의 정합화 동기화`** — 본 패치의 changelog 표
- **README `§3 dhparam 영속화` 절** — 빌드 시 굽기 + 호스트 백업/복원 hook 메커니즘
- **README `§10.3 script/test_run/` 절** — 21 개 스크립트 단계화된 회귀 검증 배터리 사용법
- **Uvicorn / Daphne 설치 / 운영 절** — 신설 nginx_uvicorn 및 devspoon 고유 daphne 스택

### Changed — 정합화 변경

- **명명 규칙 통일 (aisum 표준)**: `compose/web_service/` → `compose/web-service/` (dash), `.env.example` → `.env-example` (dash) — 6 스택 모두
- **dhparam 마운트 패턴 교체** (6 스택): `./ssl/certs:/etc/ssl/certs` (안티패턴 — 시스템 CA 번들 가림) → `./ssl/dhparam:/etc/nginx/dhparam-backup` (격리된 백업 볼륨)
- **`sample_nginx_https.conf` 의 `ssl_dhparam`** → `/etc/nginx/dhparam.pem` 으로 통일 (4 스택)
- **nginx.conf 의 ngxblocker include 경로** → devspoon Dockerfile 의 실제 install 경로 (`/etc/nginx/` 직속) 와 정합. aisum-style `/etc/nginx/ngxblocker.d/` 패턴은 채택하지 않음
- **3 스택 nginx config 동기화** (gunicorn / php / uwsgi) — aisum 베이스라인의 nginx.conf, conf.d/default.conf, generator 스크립트, sample, proxy_params 적용
- **app-server config 동기화** — gunicorn / uwsgi / php-7.3 / php-8.4 모두
- **logrotate dropin 14 개에 `su root root`** — WSL `/mnt/c` 0777 bind mount 환경에서 logrotate "potentially insecure permissions" 거부 회피
- **`entrypoint-with-cron.sh` 3 종 sanitize 추가** — bind-mount logrotate dropin 을 `/run/logrotate.d/` 로 0644 사본화
- **`docker/gunicorn/Dockerfile` 의존성 보강** — builder `libbz2-dev liblzma-dev`, runtime `libbz2-1.0 liblzma5 libnsl2 libuuid1`
- **`docker/uwsgi/Dockerfile` 의존성 보강** — 위 + `libpcre3-dev libpcre3 libxml2-dev libxml2` (uwsgi 라우팅/플러그인)
- **`docker/php-fpm/Dockerfile-7.3` 심링크** — `/usr/sbin/php-fpm7.3` → `/usr/sbin/php-fpm` (`romeoz/docker-phpfpm:7.3` 베이스 호환)
- **`script/letsencrypt.sh` 대대적 리팩토링**:
  - dead dhparam 생성/백업 코드 제거 (Dockerfile hook 으로 대체)
  - `/etc/letsencrypt/${array[0]}/letsencrypt` 영구히 false 였던 존재 체크 → `/etc/letsencrypt/live/<domain>/`
  - `certbot -w /www/$webroot_folder$domain_string` malformed 인자 → `-w /www/$webroot_folder` + `-d <domain>` 분리
  - `set -eo pipefail` + 입력 regex 검증 (도메인 / 이메일)
- **`www/django_sample/pyproject.toml`** — `[project.optional-dependencies]` 5 개 extras 추가 (gunicorn / uvicorn / daphne / uwsgi / celery). daphne 는 Django 4.0 호환 위해 3.x 트랙 핀
- **`www/django_sample/` 전체 새로고침** — aisum 의 `.python-version 3.14` 버전 적용, 잔재 Python 3.11 venv 제거
- **`config/app-server/php-{7.3,8.4}/pool.d/sample_php.conf`** — `[domain]` 섹션 헤더 + `listen=[::]:portnumber` 추가 (이전엔 placeholder 부재로 generator 가 입력값 무시한 채 sample 그대로 복사함)
- **`config/app-server/php-{7.3,8.4}/php_conf.sh`** — `set -euo pipefail`, 입력 regex 검증, sed `|` delimiter, `mkdir -p ./pool.d`

### Fixed — 라운드별 audit 수정

#### 라운드 1 (5 H + 3 M)
- **fix(audit/H1)**: `nginx_uvicorn/docker-compose.yml` 이 `nginx/gunicorn/` 마운트 → 신설된 uvicorn config dir 가 dead code 였던 버그
- **fix(audit/H2)**: `nginx_uwsgi/docker-compose.yml` 의 부재 경로 `proxy_params` 마운트 (Docker 가 호스트에 phantom 디렉토리 자동 생성)
- **fix(audit/H3)**: 4 logrotate dropin (daphne 3 + uwsgi 1) 에 `su root root` 누락
- **fix(audit/H4)**: `s2_build.sh` 가 부재 `Dockerfile` 로 php-fpm 빌드 호출 → `-f Dockerfile-7.3/8.4` 명시
- **fix(audit/M1+M2)**: `s1b_nginx_conf_generators.sh`, `s5_https.sh` 의 출력 파일명 suffix 오타 (`_http_ng` → `_ng_http`)
- **fix(audit/M3)**: php `nginx_http_conf.sh` 헤더 코멘트의 stack 명 오기

#### 라운드 2 (6 H + 3 M)
- **fix(audit2/H1)**: `php_conf.sh` sed 가 sample_php.conf 에 없는 placeholder 를 찾고 있어 generator 가 무동작이었던 치명적 버그
- **fix(audit2/H2)**: `letsencrypt.sh` dead dhparam + 경로 버그 + malformed 인자 (위 Changed 참조)
- **fix(audit2/H3+H4)**: `s3_stack_smoke.sh`, `s2a_image_inspect.sh` 의 stale aisum/redis-stats 참조 제거
- **fix(audit2/M1)**: 4 nginx.conf 주석의 ngxblocker.d 경로 drift (실제 include 는 이전 commit 에서 수정됐으나 주석은 잔존)
- **fix(audit2/M2+M3+M4)**: README s5_https.sh 예제 인자 누락 (즉시 실행 실패), s2_build.sh 설명 부정확, "16 개" → 21 개 drift
- **fix(integration)**: php-7.3 이미지 boot 결함 + pool.d sample naming 충돌
- **fix(integration)**: django_sample 의 `[project.optional-dependencies]` 부재로 모든 Python 스택 `uv sync --extra` 실패

#### 라운드 3 (운영 누락 보강)
- **feat(healthcheck)**: 6 스택 app `/dev/tcp` probe + webserver depends_on service_healthy
- **docs(README)**: §11 WSL2 운영 가이드 추가
- **feat(test_run)**: `verify_healthcheck.sh` + `verify_integration_{uvicorn,daphne,uwsgi}.sh`

### Removed — 정리

- `compose/web-service/<stack>/ssl/certs/.gitkeep` 4 개 (안티패턴 제거)
- `compose/web-service/nginx_gunicorn/ssl/certs/` 의 잔재 288 개 시스템 CA 심볼릭 링크 (잘못된 mount 흔적 — certbot 깨뜨림)
- `TEST-PLAN.md`, `handoff-1.md` (이전 PR 사이클의 핸드오프 문서)
- 모든 Python 스택의 stale `.python-version 3.11` 잔재 + 일부 `__pycache__`

### 검증 결과 (Exit Criteria)

| 영역 | 결과 |
|---|---|
| HTTPS 5 요구사항 (build/backup/restore/sample/path) | **5 / 5 PASS** |
| `verify_compose_yml.sh` | **6 / 6 PASS** |
| `verify_conf_generators.sh` | **8 / 8 PASS** (4 스택 × HTTP+HTTPS) |
| `verify_dhparam_lifecycle.sh` | **A + B + C PASS** |
| `verify_dhparam_host_wins.sh` | **PASS** |
| `verify_healthcheck.sh` (static) | **12 / 12 PASS** |
| 풀스택 통합 검증 | gunicorn / PHP 7.3 / PHP 8.4 / uvicorn / daphne 모두 **HTTP 200**, ⚠ uwsgi HTTP 500 (Django app 영역 — 별도 issue) |
| 보존 정책 회귀 | nginx_daphne / PHP 7.3+8.4 / docs/ / entrypoint-with-cron.sh / redis protected-mode yes / CELERY SSOT **모두 보존** |

### 알려진 잔여 issue

- **uwsgi Django 500** — nginx↔uwsgi_pass 통신 PASS, dhparam PASS, but Django 앱 영역. `config/app-server/uwsgi/uwsgi.ini` 의 `wsgi-file` / `chdir` / `module` 또는 `www/django_sample/config/wsgi.py` 검토 필요. 본 패치 HTTPS/dhparam 범위 외 별도 issue
- **daphne 3.x 트랙 임시 핀** — Django 4.0.6 호환 트랙. Django 4.2 LTS / 5.x bump 시 daphne / channels 4.x 로 복귀 권장
- **celery / celery-beat healthcheck** — 운영 가시성 트레이드오프로 skip. 필요 시 `celery -A config inspect ping` 추가
- **`script/letsencrypt.sh` 실 발급** — 도메인 미보유로 미검증. 도메인 확보 후 dev 환경에서 1회 검증

### 32 commits 누적 매핑

자세한 commit 메시지·hash·라운드별 분류는 [`docs/patch/2026-06-01-PATCH-001-INDEX.md`](docs/patch/2026-06-01-PATCH-001-INDEX.md) 참조.

---

이전 변경 (newflow 이전 base) 은 git log 와 GitHub Releases 참조.
