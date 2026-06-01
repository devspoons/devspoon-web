---
patch_id: PATCH-2026-06-01
doc_id: PATCH-003-IMPLEMENTATION
title: 구현 세부 — 8 영역의 변경 파일·패턴·함정·commit hash 매핑
parent: 2026-06-01-PATCH-001-INDEX.md
audience: 본 패치를 다시 적용하거나 일부만 cherry-pick 하려는 Claude/개발자
---

# PATCH-2026-06-01-003 구현

본 문서는 32개 commit 을 **8 개의 작업 영역** 으로 묶고, 각 영역별로 (a) 변경 파일 (b) 적용 패턴 (c) 발견된 함정 (d) commit hash 를 매핑합니다. Claude 가 동일 패치를 재실행할 때 각 영역을 독립적으로 처리하거나 cherry-pick 할 수 있도록 구성.

## 영역 0 — 명명·구조 통일

### 변경 파일
- `compose/web_service/` → `compose/web-service/` (디렉토리 rename, 6 스택)
- `compose/web-service/<stack>/.env.example` → `.env-example` (파일 rename, 6 스택)

### 패턴
- `git mv` 로 추적되는 rename
- 한 commit 으로 묶음 — content 변경은 다음 영역에서 별도

### 함정
- ⚠ `git mv` 후 같은 commit 안에서 파일 내용을 수정하면 git status 는 "RM" 으로 보이지만, **stage 시점에 수정사항이 포함 안 되어 있으면 commit 에 빠진다**. 본 패치에서 `fe34070` 가 rename 만 가져갔고 docker-compose.yml 의 dhparam 마운트 변경은 `9dec2f1` 에 별도 commit. **반드시 git diff HEAD 로 차이를 확인 후 다음 commit 분리**.

### Commits
- `fe34070` refactor(compose): rename + dhparam pattern 의도 선언

## 영역 1 — dhparam 영속화 (HTTPS 5 요구사항의 핵심)

### 변경 파일
- `docker/nginx/Dockerfile` — 섹션 8 (build 시 dhparam 굽기) + 섹션 9 (entrypoint hook)
- `compose/web-service/<6 stacks>/docker-compose.yml` — `./ssl/dhparam/:/etc/nginx/dhparam-backup/` 마운트 추가
- `compose/web-service/<6 stacks>/ssl/dhparam/.gitkeep` — 빈 백업 디렉토리 추적
- `compose/web-service/<6 stacks>/ssl/certs/.gitkeep` — 안티패턴 제거
- `config/web-server/nginx/<4 stacks>/sample_nginx_https.conf` — `ssl_dhparam /etc/nginx/dhparam.pem;` 으로 통일

### 패턴 (3 단계)

```
빌드 시점 (Dockerfile #8):
  openssl dhparam -out /etc/nginx/dhparam.pem 2048

기동 직전 hook (Dockerfile #9 → /docker-entrypoint.d/20-dhparam.sh):
  BK=/etc/nginx/dhparam-backup/dhparam.pem
  LV=/etc/nginx/dhparam.pem
  mkdir -p /etc/nginx/dhparam-backup
  if [ -s "$BK" ]; then cp -f "$BK" "$LV"   # 복원
  else                  cp -f "$LV" "$BK"   # 최초 백업
  fi

compose 마운트:
  ./ssl/dhparam/:/etc/nginx/dhparam-backup/
```

### 동작 (3 시나리오)

| 시나리오 | hook 동작 | 결과 |
|---|---|---|
| 최초 기동 (host backup 비어 있음) | LV → BK 백업 | 호스트에 영속 키 1개 생성 |
| docker compose down → up | BK 존재 → BK → LV 복원 | 동일 키 유지 |
| 이미지 재빌드 (새 dhparam 굽힘) | BK 존재 → BK → LV 복원 | 운영 키 유지 (호스트가 우선) |

### 함정
- ⚠ **과거 안티패턴**: `./ssl/certs:/etc/ssl/certs` 통째 마운트 → 시스템 CA 번들 (`/etc/ssl/certs/ca-certificates.crt`) 을 가려 certbot 발급이 깨졌음. 본 패치로 완전 제거.
- ⚠ nginx_gunicorn 에 잔존한 288 개 CA 심볼릭 링크 발견 → 일괄 삭제
- ⚠ dhparam 은 비밀이 아님 (RFC 7919) — 전 도메인 공유 1 key 로 충분

### Commits
- `9dec2f1` feat(compose): mount ssl/dhparam as backup volume across 6 stacks
- `d945876` feat(nginx): bake dhparam at build + restore-from-backup entrypoint hook

## 영역 2 — nginx 설정 동기화 + uvicorn 신설

### 변경 파일
- `config/web-server/nginx/{gunicorn,php,uwsgi}/nginx_conf/nginx.conf` (3 → aisum 베이스라인)
- `config/web-server/nginx/{gunicorn,php,uwsgi}/conf.d/default.conf` (catch-all hardening)
- `config/web-server/nginx/{gunicorn,php,uwsgi}/nginx_http_conf.sh` + `nginx_https_conf.sh` (한국어 도움말, 입력 검증, single-pass sed)
- `config/web-server/nginx/{gunicorn,php,uwsgi}/sample_nginx_http.conf` + `sample_nginx_https.conf` (aisum 템플릿)
- `config/web-server/nginx/{gunicorn,php,uwsgi}/proxy_params/proxy_params` (+ uwsgi 의 `uwsgi_params`, php 의 `fastcgi/fastcgi_params`)
- **NEW** `config/web-server/nginx/uvicorn/` 전체 — devspoon 에 누락되어 있던 디렉토리. aisum 의 nginx_uvicorn 구조를 그대로 가져옴

### 적용 패턴
- aisum 베이스라인을 직접 덮어쓰기. devspoon 고유 코드는 없는 영역이라 안전.
- `nginx_uvicorn` compose 스택은 이미 존재했으나 nginx config 가 없어 dead — 본 패치로 완성.

### 함정 (라운드 1·2 에서 발견)
- ⚠ aisum 의 nginx.conf 는 `include /etc/nginx/ngxblocker.d/...` (서브디렉토리) — devspoon Dockerfile 은 `install-ngxblocker -c /etc/nginx` (직속) → **mismatch 로 nginx -t 즉시 실패**. `e44865a` 와 `0a0d5a7` 두 commit 으로 nginx.conf 의 include 경로를 devspoon Dockerfile 의 실제 install 경로(`/etc/nginx/{botblocker-nginx-settings,globalblacklist}.conf`)로 맞춤.
- ⚠ `nginx_uvicorn/docker-compose.yml` 가 처음에는 `nginx/gunicorn/` 디렉토리를 마운트하고 있었음(`174126a` 에서 `nginx/uvicorn/` 으로 교정).

### Commits
- `e93661b` feat(nginx-conf): sync 3 stacks + add missing nginx_uvicorn stack
- `e44865a` fix(nginx): align ngxblocker include paths with devspoon Dockerfile install location
- `174126a` fix(audit/H1): uvicorn webserver mounts dedicated nginx/uvicorn config dir
- `360af6e` fix(audit/H2): nginx_uwsgi mounts existing uwsgi_params (not phantom proxy_params)
- `0a0d5a7` docs(audit2/M1): ngxblocker path drift in nginx.conf comments (4 files)
- `59eeca4` docs(audit/M3): correct stack name in php nginx_http_conf.sh header

## 영역 3 — app-server 설정 동기화

### 변경 파일
- `config/app-server/gunicorn/gunicorn.conf.py`
- `config/app-server/uwsgi/{uwsgi.ini, sample_uwsgi.ini, uwsgi_conf.sh, uwsgi_config.py}`
- `config/app-server/php-7.3/{php_conf.sh, php_ini/php.ini, pool.d/sample_php.conf, sample_php.conf}` (양 버전 동일 적용)
- `config/app-server/php-8.4/{php_conf.sh, php_ini/php.ini, pool.d/sample_php.conf, sample_php.conf}`
- **NEW** `config/app-server/uvicorn/gunicorn_uvicorn.conf.py` (gunicorn + UvicornWorker for ASGI prefork)

### 함정 (라운드 2 에서 발견)
- ⚠ `php_conf.sh` 의 sed 가 sample_php.conf 에 **없는** placeholder (`domain`, `portnumber`) 를 찾고 있었음 → generator 가 입력값을 무시한 채 sample 원본을 그대로 copy 했음. 모든 pool 이 `[sample]` 헤더로 충돌. `b6a30c8` 에서 sample 에 `[domain]` + `listen=[::]:portnumber` 추가하여 generator 가 실제로 동작하도록 수정.

### Commits
- `49dda29` feat(app-server): sync gunicorn/uwsgi/php configs with aisum-infrakit
- `b6a30c8` fix(audit2/H1): php_conf.sh + sample_php.conf placeholders actually work
- `da82200` fix(integration): php-7.3 image + pool.d sample naming so php-fpm boots

## 영역 4 — Dockerfile 의존성·entrypoint 보강

### 변경 파일
- `docker/gunicorn/Dockerfile` — builder/runtime 의존성 보강
- `docker/uwsgi/Dockerfile` — 동일 + uwsgi 라우팅/플러그인 native deps
- `docker/{gunicorn,uwsgi,php-fpm}/entrypoint-with-cron.sh` — logrotate dropin sanitize
- `docker/php-fpm/Dockerfile-7.3` — `/usr/sbin/php-fpm7.3` 심링크 추가 (`romeoz/docker-phpfpm:7.3` 베이스가 plain `php-fpm` 미제공)

### 패턴

```bash
# gunicorn/uwsgi builder 보강
apt-get install -y libbz2-dev liblzma-dev      # Python stdlib (bz2/lzma)

# gunicorn/uwsgi runtime 보강
apt-get install -y libbz2-1.0 liblzma5 libnsl2 libuuid1

# uwsgi 추가
apt-get install -y libpcre3-dev/libpcre3 libxml2-dev/libxml2

# entrypoint-with-cron.sh — logrotate sanitize
mkdir -p /run/logrotate.d
for f in /etc/logrotate.d/*; do
  install -m 0644 -o root -g root "$f" /run/logrotate.d/$(basename "$f")
done
```

### 함정
- ⚠ WSL /mnt/c bind-mount 가 file mode 0777 로 노출 → logrotate "potentially insecure permissions" 거부 → 사본 패턴으로 회피
- ⚠ `romeoz/docker-phpfpm:7.3` 베이스는 `/usr/sbin/php-fpm7.3` 만 있음. compose `command: ["php-fpm", ...]` 즉시 not found 종료. 심링크 추가로 해결.

### Commits
- `7c47e4f` fix(docker): bring stdlib + native deps from aisum-infrakit, sanitize logrotate dropins
- `da82200` fix(integration): php-7.3 image + pool.d sample naming so php-fpm boots

## 영역 5 — scripts (test_run + logrotate + letsencrypt)

### 변경 파일
- **NEW** `script/test_run/*` 16 개 → 라운드 2/3 에서 5개 verify_*.sh 추가 → 총 21+ 개
- `script/logrotate/*/<dropin>` 14 개에 `su root root` 디렉티브 추가 (WSL 0777 회피)
- `script/letsencrypt.sh` 대대적 리팩토링 — dead dhparam 코드 제거 + 경로 버그 + 입력 검증

### test_run 21 개 (정식)
| 파일 | 역할 |
|---|---|
| `s0_prereq.sh` | docker/compose/uv/log 디렉토리 사전 점검 |
| `s1b_exit_check.sh` | 컨테이너 비정상 종료 진단 |
| `s1b_nginx_conf_generators.sh` | 5 스택 conf 생성기 회귀 |
| `s2_build.sh` | 스택별 Dockerfile 격리 빌드 (php-fpm 7.3/8.4 양변) |
| `s2a_image_inspect.sh` | 빌드 이미지 메타 검사 |
| `s3_stack_smoke.sh` | 단일 스택 기동 → curl → cleanup |
| `s5_https.sh` | dhparam 마운트/복원, sample 치환, nginx -t (certbot 제외) |
| `s6_regression.sh` | 통합 회귀 |
| `ssl_diag.sh` | dhparam 경로 + SHA 비교 |
| `verify_block.sh` | 봇/스캐너 차단 검증 |
| `celery_diag.sh`, `check_cgi.sh`, `check_cgi2.sh`, `check_excode.sh`, `inspect_orphans.sh`, `sim_exit.sh` | 보조 진단 |
| `verify_compose_yml.sh` | 6 스택 compose YAML + dhparam 마운트 + 안티패턴 부재 |
| `verify_conf_generators.sh` | 4 스택 × HTTP+HTTPS 생성기 |
| `verify_dhparam_lifecycle.sh` | A/B/C 3단계 백업/복원 |
| `verify_dhparam_host_wins.sh` | 호스트 백업이 이미지 dhparam 을 덮어쓰는지 |
| `verify_nginx_standalone.sh` | 실제 컨테이너 기동 + 전체 마운트 |
| `verify_healthcheck.sh` | 6 스택 healthcheck + depends_on 정적 + 런타임 |
| `verify_integration_uvicorn.sh` / `verify_integration_daphne.sh` / `verify_integration_uwsgi.sh` | per-stack 풀스택 통합 |

### 함정 (라운드 2 에서 발견)
- ⚠ aisum 의 test_run 은 ROOT 를 `/mnt/c/.../aisum-infrakit` 으로 하드코딩. devspoon 으로 sed 일괄 치환 필요 (`38ea6ac` 에서 처리).
- ⚠ `s2a_image_inspect.sh` 가 aisum 의 `with-cron.sh`, `aisum-logrotate.sh`, `40-start-cron.sh` 등 devspoon 부재 파일을 가정 → `f4aaeff` 에서 devspoon 실제 파일명 (`entrypoint-with-cron`, `20-dhparam.sh`) 으로 교정.
- ⚠ `s3_stack_smoke.sh` 가 제거된 `redis-stats`, 부재 `aisum-logrotate.sh` 참조 → 같은 commit 에서 SKIP/대체.
- ⚠ `s1b_nginx_conf_generators.sh`, `s5_https.sh` 가 출력 파일명 suffix 를 `_http_ng.conf` 로 찾았으나 실제는 `_ng_http.conf` (`ec2b2ec` 에서 교정).
- ⚠ `s2_build.sh` 가 `docker build docker/php-fpm/` 호출 — 해당 디렉토리에는 Dockerfile 없고 `Dockerfile-7.3` / `Dockerfile-8.4` 만 있음. `15da78b` 에서 `-f` 명시 + 두 변형 빌드로 교정.
- ⚠ `script/letsencrypt.sh` 의 `/etc/letsencrypt/${array[0]}/letsencrypt` 존재 체크는 영구히 false (실제 경로는 `/etc/letsencrypt/live/<domain>/`). `1b82cf9` 에서 교정.
- ⚠ `script/letsencrypt.sh` 의 `certbot -w /www/$webroot_folder$domain_string` 는 webroot 와 domain 문자열이 join 된 malformed 인자. 같은 commit 에서 `-w /www/$webroot_folder` 와 `-d <domain>` 분리.
- ⚠ 14개 logrotate dropin 중 daphne/daphne-celery/daphne-celerybeat + uwsgi/uwsgi 4개가 첫 라운드에서 누락됨. `35a6d39` 에서 `su root root` 추가.

### Commits
- `38ea6ac` feat(scripts): import aisum-infrakit test_run battery + logrotate su root
- `2ad6a5c` feat(test_run): add verifier scripts for dhparam + compose + conf-generator
- `89e5710` fix(audit): harden dhparam lifecycle test for parallel runs and slow WSL bind mounts
- `457b254` fix(test): harden verify_nginx_standalone against early nginx exit
- `35a6d39` fix(audit/H3): add 'su root root' to 4 missed logrotate dropins (daphne + uwsgi)
- `15da78b` fix(audit/H4): s2_build.sh builds both php-fpm Dockerfile variants explicitly
- `ec2b2ec` fix(audit/M1+M2): test_run scripts use correct generator output suffix
- `f4aaeff` fix(audit2/H3+H4): test_run scripts drop stale aisum/redis-stats references
- `1b82cf9` fix(audit2/H2): letsencrypt.sh — dead code + path bugs + input validation
- `d36a823` feat(test_run): add verify_healthcheck.sh smoke validator
- `6a4df02` feat(test_run): per-stack full-stack integration verifiers

## 영역 6 — www 샘플 이전

### 변경 파일
- `www/django_sample/` — aisum 버전 (`.python-version 3.14`, 패키지 최신화)
- `www/php_sample/` — aisum 버전
- **NEW** `www/fastapi_sample/` — uv-managed FastAPI
- **NEW** `www/flask_sample/` — uv-managed Flask
- **NEW** `www/certbot/` — ACME webroot 표준 위치 (`.gitkeep` 만)

### 함정 (라운드 3 에서 발견)
- ⚠ `www/django_sample/pyproject.toml` 에 `[project.optional-dependencies]` 가 부재 → 모든 Python 스택의 compose `command: uv sync --extra <stack>` 가 실패 → 라운드 3 의 `7c68c33` 에서 5 개 extras (gunicorn/uvicorn/daphne/uwsgi/celery) 추가. daphne 는 Django 4.0 호환 위해 3.x 트랙 핀.
- ⚠ uv.lock 도 함께 재생성 (`edbc40e`).

### Commits
- `fc323c0` feat(www): sync samples with aisum-infrakit (django/fastapi/flask/php/certbot)
- `7c68c33` fix(integration): add missing [project.optional-dependencies] to django_sample
- `edbc40e` chore(deps): refresh django_sample/uv.lock to match new extras

## 영역 7 — healthcheck + WSL 운영 가이드 + README

### 변경 파일
- `compose/web-service/<6 stacks>/docker-compose.yml` — app healthcheck + webserver depends_on service_healthy
- `script/test_run/verify_healthcheck.sh` — 정적/런타임 검증
- `README.md` — §0.5.9 정합화 changelog, §3 dhparam 영속화, §10.3 test_run, §11 WSL2 운영 가이드, uvicorn/daphne 설치 절, www 샘플 절

### 패턴 (healthcheck)

```yaml
# Python 스택 (gunicorn/uvicorn/uwsgi/daphne) — port 8000
healthcheck:
  test: ["CMD-SHELL", "bash -c '</dev/tcp/127.0.0.1/8000' || exit 1"]
  interval: 10s
  timeout: 3s
  retries: 5
  start_period: 30s    # uv sync cold start 보호

# PHP 스택 — port 9000 (FastCGI)
healthcheck:
  test: ["CMD-SHELL", "bash -c '</dev/tcp/127.0.0.1/9000' || exit 1"]
  ...

# nginx webserver
depends_on:
  <app-service>:
    condition: service_healthy
  redis:                # Python 스택만. PHP 는 profile: redis 라 제외
    condition: service_healthy
```

### 함정
- ⚠ `bash -c '</dev/tcp/...'` 는 모든 베이스 이미지에 bash 가 있어야 동작. Ubuntu 24.04 / Debian bookworm / romeoz-phpfpm:7.3 모두 bash 기본 포함이라 무해.
- ⚠ celery / celery-beat 는 healthcheck 미적용 (`celery -A <app> inspect ping` 비용 큼) — 운영 가시성 필요 시 별도 작업.
- ⚠ WSL `/etc/wsl.conf` 의 `[automount] fmask=11` 권장. 기본 `fmask=177` 은 `/mnt/c` 의 모든 파일을 0600 으로 잘라 redis/nginx/php-fpm 가 conf 를 못 읽음. README §11 에 안내.

### Commits
- `587a136` docs(README): document aisum-infrakit sync (paths, dhparam, uvicorn, test_run, samples)
- `aea505b` docs(audit2/M2+M3+M4): correct README drift on test_run
- `bf8b6c4` feat(healthcheck): add /dev/tcp probes to all 6 app services
- `af0e98c` docs(README): add §11 WSL2 operations guide + dhparam permission notes

## 영역간 의존성 (cherry-pick 시 주의)

```
영역 0 (rename) ─┬─→ 영역 1 (dhparam)        # rename 후에 docker-compose 의 새 경로에 dhparam 마운트
                ├─→ 영역 2 (nginx config)    # 새 폴더명 (web-service) 에 conf 동기화
                ├─→ 영역 3 (app-server)      # uvicorn 신설은 영역 2 의 nginx_uvicorn 과 짝
                ├─→ 영역 4 (Dockerfile)
                ├─→ 영역 5 (scripts)         # test_run 의 ROOT 가 새 경로
                ├─→ 영역 6 (www)
                └─→ 영역 7 (healthcheck/README)
영역 1 (dhparam) ─→ 영역 7 (README §3)
영역 2,3 ─→ 영역 5 (test_run 이 영역 2,3 의 산출물을 검증)
영역 5 ─→ 영역 7 (verify_*.sh 가 README §10.3 에 문서화)
```

cherry-pick 권장 순서: 0 → 1 → 4 → 2,3 (병렬) → 5 → 6 → 7
