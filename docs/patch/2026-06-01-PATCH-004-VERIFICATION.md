---
patch_id: PATCH-2026-06-01
doc_id: PATCH-004-VERIFICATION
title: 검증 절차 — verify_*.sh 6개 + 풀스택 통합 테스트 + HTTPS 5요구사항
parent: 2026-06-01-PATCH-001-INDEX.md
audience: 패치 적용 후 회귀 여부를 종합 판단하려는 Claude/개발자
exit_criteria: 본 문서의 "최종 합격 기준" 절을 100% 만족해야 패치 완료
---

# PATCH-2026-06-01-004 검증

본 문서는 본 패치가 **회귀 없이 동작하는지 종합 판단** 하기 위한 검증 절차입니다. Claude 가 같은 패치를 다시 적용할 때 "완료" 라고 선언하기 전에 본 문서의 모든 절차가 PASS 여야 합니다.

## 0. 검증 환경 사전 조건

| 항목 | 필요 값 | 확인 명령 |
|---|---|---|
| OS | Linux / WSL2 Ubuntu | `uname -a` |
| Docker | 24+ (Engine), Compose v2+ | `docker version; docker compose version` |
| 포트 | 80 / 443 / 6379 / 5555 가용 | `ss -lntp \| grep -E ':(80\|443\|6379\|5555)'` |
| 디스크 여유 | 10 GB+ (Python 빌드 시 임시 확장) | `df -h /var/lib/docker` |
| WSL `wsl.conf` | `fmask=11` (또는 권한 사후 조정 가능) | `cat /etc/wsl.conf` |
| 작업 디렉토리 | devspoon-web 루트 | `git rev-parse --show-toplevel` |

**WSL 호스트 추가 작업** (한 번만):
```bash
chmod 644 compose/web-service/*/redis/conf/redis.conf
chmod 644 www/php_sample/index.php
chmod +x script/test_run/*.sh
```

## 1. 단위 검증 — verify_*.sh 6 종

본 패치가 추가한 6 개 verify_*.sh 를 다음 순서로 실행. 모두 exit 0 + PASS 메시지가 필요.

### 1.1 `verify_compose_yml.sh` — 6 스택 docker-compose.yml 정합

```bash
bash script/test_run/verify_compose_yml.sh
# Expected:
#   [PASS] compose YAML valid
#   [PASS] ssl/dhparam -> /etc/nginx/dhparam-backup mount present
#   [PASS] no ssl/certs anti-pattern
# (위 3 줄이 6 스택 모두 반복)
#   === Summary: 6 passed, 0 failed ===
```

### 1.2 `verify_conf_generators.sh` — 4 스택 × HTTP+HTTPS 생성기

```bash
bash script/test_run/verify_conf_generators.sh
# Expected: 8 PASS (gunicorn/uvicorn/uwsgi/php × http/https)
#   각 HTTPS conf 에 ssl_dhparam=/etc/nginx/dhparam.pem 라인 + ssl_certificate 경로 출력
```

### 1.3 `verify_dhparam_lifecycle.sh` — A/B/C 3 단계

```bash
# 호스트 백업 dhparam 이 있으면 STEP-A 가 다른 의미로 동작 — 사전 삭제 권장
rm -f compose/web-service/nginx_gunicorn/ssl/dhparam/dhparam.pem
bash script/test_run/verify_dhparam_lifecycle.sh
# Expected:
#   [PASS-A] image dhparam was backed up to host on first run
#   [PASS-B] container has the host backup value after restart
#   [PASS-C] host backup wins on restore (image dhparam was overwritten)
#   === ALL PASS ===
```

### 1.4 `verify_dhparam_host_wins.sh` — STEP-C 의 독립 검증

```bash
bash script/test_run/verify_dhparam_host_wins.sh
# Expected:
#   [PASS-C] host backup wins (image dhparam was overridden by host backup)
```

### 1.5 `verify_healthcheck.sh` — 6 스택 healthcheck 정적

```bash
RUNTIME=0 bash script/test_run/verify_healthcheck.sh   # 빠른 정적 검증
# Expected: 12 PASS (6 스택 × healthcheck + depends_on 2개씩)
#   === Static summary: 12 passed, 0 failed ===

# 런타임 검증 (선택, ~2 분):
STACK=nginx_php-8.4 bash script/test_run/verify_healthcheck.sh
# Expected: 위 + healthy 상태 도달 확인
```

### 1.6 `verify_nginx_standalone.sh` — 실제 컨테이너 기동 시뮬

```bash
bash script/test_run/verify_nginx_standalone.sh
# Expected: 컨테이너 기동 → entrypoint hook 실행 → 호스트 백업 dhparam 생성 → SHA 일치 PASS
# (nginx 자체는 upstream gunicorn-app 미존재로 종료하지만 hook 까지는 동작)
```

## 2. 풀스택 통합 검증 — 5 스택 docker compose up

각 스택을 실제로 띄워 200/healthy 까지 확인. 본 패치가 가장 깊게 검증된 영역.

### 2.1 사전 — 이미지 빌드 (한 번만)

```bash
# nginx 이미지 — 모든 스택 공유
docker build -t devspoon-nginx:latest docker/nginx/

# Python 앱 이미지 — gunicorn/uvicorn/daphne 공유
docker build -t devspoon-py-app:latest docker/gunicorn/

# uwsgi 앱 이미지 — uwsgi 스택 전용
docker build -t devspoon-uwsgi-app:latest docker/uwsgi/

# PHP 앱 이미지 — 두 변형
docker build -f docker/php-fpm/Dockerfile-7.3 -t devspoon-php-app:7.3 docker/php-fpm/
docker build -f docker/php-fpm/Dockerfile-8.4 -t devspoon-php-app:8.4 docker/php-fpm/
```

### 2.2 스택별 verify_integration_*.sh

```bash
# uvicorn 풀스택
bash script/test_run/verify_integration_uvicorn.sh
# Expected: HTTP 200, dhparam SHA 일치, down/up 후 dhparam 보존

# daphne 풀스택
bash script/test_run/verify_integration_daphne.sh
# Expected: HTTP 200, dhparam SHA 일치

# uwsgi 풀스택
bash script/test_run/verify_integration_uwsgi.sh
# Expected: uwsgi-app Up (healthy), dhparam SHA 일치
# ⚠ HTTP 500 (Django app 영역 — 본 패치 범위 외)
```

### 2.3 gunicorn / PHP 풀스택 (라운드 2 에서 검증됨)

`s3_stack_smoke.sh` 또는 verify_integration 유사 패턴으로 검증 가능. 라운드 2 에서 다음이 확인됨:
- gunicorn: HTTP 200 (Django)
- PHP 7.3: HTTP 200 (phpinfo PHP 7.3.10)
- PHP 8.4: HTTP 200 (phpinfo PHP 8.4.21)

## 3. HTTPS 5 요구사항 검증 (사용자 원본 요청)

본 패치의 **수락 기준** 인 사용자의 5 가지 HTTPS 검증 요구사항. 각각의 검증 명령과 기대값:

| # | 요구사항 | 검증 명령 | 기대값 |
|---|---|---|---|
| 1 | docker build 시 보안키 생성 | `docker run --rm devspoon-nginx:latest head -1 /etc/nginx/dhparam.pem` | `-----BEGIN DH PARAMETERS-----` |
| 2 | 키 호스트 백업 | `verify_dhparam_lifecycle.sh STEP-A` | `[PASS-A]` |
| 3 | down/up 후 복구 | `verify_dhparam_lifecycle.sh STEP-B + STEP-C` | `[PASS-B] [PASS-C]` |
| 4 | nginx https 샘플 생성 | `verify_conf_generators.sh` | 4 스택 × HTTPS PASS |
| 5 | 경로 설정 정합 | `grep ssl_dhparam config/web-server/nginx/*/sample_nginx_https.conf` | 모두 `/etc/nginx/dhparam.pem` |

### certbot 발급은 의도적 미실행 (도메인 없음)

`script/letsencrypt.sh` 의 발급 흐름은 코드 리뷰로만 검증 (`PATCH-005` 의 라운드 2 audit2/H2 참조).

## 4. README 정합성 검증

```bash
# 새 경로 (dash) 가 잔존 underscore 와 혼재하지 않는지
grep -n 'compose/web_service' README.md   # 0 line — drift 없음
grep -n '\.env\.example' README.md         # 0 line (단, audit2 changelog 의 인용은 예외)

# 필수 절 존재
grep -n '^## 디렉토리 구조\|^### 11. WSL2\|dhparam 영속화' README.md   # 3+ matches

# 새 스택 / 샘플 언급
grep -n 'nginx_uvicorn\|fastapi_sample\|flask_sample\|certbot' README.md   # 다수 matches
```

## 5. 보존 정책 회귀 검증

본 패치가 의도적으로 보존한 devspoon 고유 자산이 사라지지 않았는지:

```bash
# nginx_daphne 스택 존재
test -d compose/web-service/nginx_daphne && test -f compose/web-service/nginx_daphne/docker-compose.yml

# PHP 두 버전
test -f docker/php-fpm/Dockerfile-7.3 && test -f docker/php-fpm/Dockerfile-8.4
test -d config/app-server/php-7.3 && test -d config/app-server/php-8.4

# docs/operations-guide
ls docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-00*.md | wc -l   # 6 개

# entrypoint-with-cron.sh 3개
ls docker/{gunicorn,uwsgi,php-fpm}/entrypoint-with-cron.sh

# redis protected-mode yes (6 stacks)
grep -l 'protected-mode yes' compose/web-service/*/redis/conf/redis.conf | wc -l   # 6

# CELERY SSOT (compose 가 합성)
grep -l 'CELERY_BROKER_URL=redis://:\${REDIS_PASSWORD' compose/web-service/*/docker-compose.yml | wc -l   # 4 (Python stacks)
```

## 6. 최종 합격 기준 (Exit Criteria)

**모두 만족해야 패치 완료**:

- [ ] verify_compose_yml.sh: 6 / 0 PASS
- [ ] verify_conf_generators.sh: 8 / 0 PASS
- [ ] verify_dhparam_lifecycle.sh: A + B + C 모두 PASS
- [ ] verify_dhparam_host_wins.sh: PASS-C
- [ ] verify_healthcheck.sh (RUNTIME=0): 12 / 0 PASS
- [ ] verify_nginx_standalone.sh: dhparam 백업 PASS
- [ ] verify_integration_uvicorn.sh: HTTP 200 + dhparam PASS
- [ ] verify_integration_daphne.sh: HTTP 200 + dhparam PASS
- [ ] verify_integration_uwsgi.sh: dhparam PASS (uwsgi 의 500 은 별도 issue 로 기록 후 진행 가능)
- [ ] HTTPS 5 요구사항 (위 §3) 5/5
- [ ] README 정합성 검증 (위 §4) 모두 PASS
- [ ] 보존 정책 회귀 검증 (위 §5) 모두 PASS
- [ ] 32 commits 가 atomic 하고 각 commit 메시지가 "왜" 를 포함

## 7. 알려진 잔여 issue (본 패치 외 별도 작업)

| Issue | 상태 | 다음 액션 |
|---|---|---|
| uwsgi Django 500 | nginx↔uwsgi 통신 OK, dhparam OK, Django 앱 영역 | 별도 issue. `config/app-server/uwsgi/uwsgi.ini` 의 `wsgi-file` / `chdir` / `module` 또는 `www/django_sample/config/wsgi.py` 검토 |
| daphne 3.x 트랙 임시 핀 | 의도된 임시 | Django 4.0.6 → 4.2 LTS 또는 5.x bump 시 daphne/channels 4.x 로 복귀 |
| celery / celery-beat healthcheck | skip | 필요 시 `celery -A config inspect ping` 로 추가 |
| `script/letsencrypt.sh` 실 발급 | 도메인 없어 미검증 | 도메인 확보 후 dev 환경에서 1회 검증 |
