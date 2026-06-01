---
patch_id: PATCH-2026-06-01
doc_id: PATCH-006-RUNBOOK
title: 재현 RUNBOOK — 다른 환경에 동일 패치를 적용하는 단계별 명령
parent: 2026-06-01-PATCH-001-INDEX.md
audience: 본 패치를 새 fork / 새 milestone / 다른 사내 인프라에 다시 적용해야 하는 Claude
estimated_duration: 2-4 시간 (이미지 빌드 30분 포함, 검증 30분 포함)
prerequisites: WSL2 Ubuntu + Docker 24+ + Compose v2+ + 디스크 10GB+
---

# PATCH-2026-06-01-006 RUNBOOK

본 문서는 Claude 가 **본 패치를 0 부터 재실행** 할 때 따라가는 결정적 명령 시퀀스입니다. 단계별 의사결정 트리를 포함하므로 환경 차이가 있어도 적응 가능.

## Phase 0 — 사전 진단 (5 분)

### 0.1 환경 확인

```bash
# 필수 도구
docker version | grep -i version
docker compose version
git --version
uv --version          # 선택: 호스트 dev 용

# 디스크 여유
df -h /var/lib/docker

# 포트
ss -lntp 2>/dev/null | grep -E ':(80|443|6379|5555)\b' || echo "(all clear)"

# WSL 인지
test -f /etc/wsl.conf && echo "WSL detected" || echo "Linux native"
```

### 0.2 의사결정 트리 — 어떤 영역을 적용할지

```
타겟 저장소가 이미 'compose/web-service/' (dash) 인가?
   YES → Phase 1 (영역 0) skip
   NO  → Phase 1 부터 실행

타겟이 PHP 단일 버전인가, 두 변형(7.3+8.4) 인가?
   단일 → PHP 부분의 7.3/8.4 분기 명령 skip
   두 변형 → 그대로 실행

타겟에 nginx_daphne 스택이 있는가?
   YES → daphne 보존 명령 실행
   NO  → daphne 관련 단계 skip

타겟이 WSL 인가, Linux native 인가?
   WSL → logrotate 의 'su root root' + entrypoint sanitize 필수
   native → 같은 변경 무해하므로 그대로 적용

certbot 발급을 함께 검증할 도메인이 있는가?
   YES → Phase 5 에 letsencrypt 발급 절차 추가
   NO  → 본 RUNBOOK 의 HTTPS 검증 (certbot 제외) 그대로
```

## Phase 1 — 명명·구조 통일 (10 분)

### 1.1 디렉토리 rename (dash 화)

```bash
cd <repo-root>
git mv compose/web_service compose/web-service
```

### 1.2 `.env.example` → `.env-example` (6 스택)

```bash
for d in compose/web-service/*/; do
  if [ -f "$d/.env.example" ]; then
    git mv "$d/.env.example" "$d/.env-example"
  fi
done
```

### 1.3 commit (rename only)

```bash
git commit -m "refactor(compose): align with aisum-infrakit naming + dhparam pattern intent"
```

## Phase 2 — dhparam 영속화 (20 분)

### 2.1 docker-compose.yml 의 volume 교체 (6 스택)

각 `compose/web-service/<stack>/docker-compose.yml` 의 webserver 서비스 volumes 에서:
```yaml
# 제거
- ./ssl/certs/:/etc/ssl/certs/         # ← 안티패턴

# 추가
- ./ssl/dhparam/:/etc/nginx/dhparam-backup/   # ← dhparam 백업
```

### 2.2 호스트 디렉토리 준비

```bash
for d in compose/web-service/*/; do
  mkdir -p "$d/ssl/dhparam"
  touch "$d/ssl/dhparam/.gitkeep"
  git rm --cached -f "$d/ssl/certs/.gitkeep" 2>/dev/null || true
  rm -rf "$d/ssl/certs"
done
```

### 2.3 `docker/nginx/Dockerfile` 에 섹션 8, 9 추가

마지막 RUN 뒤에 다음 두 RUN 추가:
```dockerfile
# 섹션 8 — 이미지에 dhparam 굽기 (build 시 1회)
RUN openssl dhparam -out /etc/nginx/dhparam.pem 2048 && \
    chmod 644 /etc/nginx/dhparam.pem

# 섹션 9 — entrypoint hook (호스트 백업 ↔ 컨테이너 dhparam 자동 동기)
RUN printf '#!/bin/sh\nset -e\nBK=/etc/nginx/dhparam-backup/dhparam.pem\nLV=/etc/nginx/dhparam.pem\nmkdir -p /etc/nginx/dhparam-backup\nif [ -s "$BK" ]; then\n  cp -f "$BK" "$LV"\nelse\n  cp -f "$LV" "$BK"\nfi\n' > /docker-entrypoint.d/20-dhparam.sh && \
    chmod +x /docker-entrypoint.d/20-dhparam.sh
```

### 2.4 4 sample_nginx_https.conf 의 `ssl_dhparam` 경로 통일

```bash
for f in config/web-server/nginx/{gunicorn,uvicorn,uwsgi,php}/sample_nginx_https.conf; do
  sed -i 's|ssl_dhparam .*|ssl_dhparam /etc/nginx/dhparam.pem;|' "$f"
done
```

### 2.5 commits (2 개 분리 권장)

```bash
git add compose/web-service/*/docker-compose.yml compose/web-service/*/ssl/
git commit -m "feat(compose): mount ssl/dhparam as backup volume across 6 stacks"

git add docker/nginx/Dockerfile config/web-server/nginx/*/sample_nginx_https.conf
git commit -m "feat(nginx): bake dhparam at build + restore-from-backup entrypoint hook"
```

## Phase 3 — Dockerfile 의존성 보강 (10 분, build 무관)

### 3.1 Python builder/runtime 보강

`docker/gunicorn/Dockerfile` 과 `docker/uwsgi/Dockerfile` 의 builder/runtime 스테이지에 다음 패키지 추가:
- builder: `libbz2-dev liblzma-dev`
- runtime: `libbz2-1.0 liblzma5 libnsl2 libuuid1`
- uwsgi 추가: builder `libpcre3-dev libxml2-dev`, runtime `libpcre3 libxml2`

### 3.2 entrypoint-with-cron.sh 의 logrotate sanitize 추가

3 개 파일 (`docker/{gunicorn,uwsgi,php-fpm}/entrypoint-with-cron.sh`) 의 cron 시작 직전에:
```bash
# WSL bind-mount 의 0777 권한을 우회: dropin 을 0644 사본으로 변환
mkdir -p /run/logrotate.d
for f in /etc/logrotate.d/*; do
  install -m 0644 -o root -g root "$f" /run/logrotate.d/$(basename "$f")
done
```

### 3.3 PHP 7.3 심링크 추가

`docker/php-fpm/Dockerfile-7.3` 의 마지막에:
```dockerfile
RUN ln -sf /usr/sbin/php-fpm7.3 /usr/sbin/php-fpm
```

### 3.4 commit

```bash
git add docker/gunicorn/Dockerfile docker/uwsgi/Dockerfile \
        docker/gunicorn/entrypoint-with-cron.sh docker/uwsgi/entrypoint-with-cron.sh \
        docker/php-fpm/entrypoint-with-cron.sh docker/php-fpm/Dockerfile-7.3
git commit -m "fix(docker): stdlib + native deps, sanitize logrotate dropins, php-7.3 symlink"
```

## Phase 4 — nginx config 동기화 + uvicorn 신설 (20 분)

### 4.1 nginx_uvicorn 디렉토리 생성

```bash
mkdir -p config/web-server/nginx/uvicorn/{conf.d,nginx_conf,proxy_params}
```

다음 7 파일을 aisum-infrakit 또는 기존 패치의 nginx_gunicorn 을 base 로 작성:
- `nginx_conf/nginx.conf`
- `conf.d/default.conf`
- `nginx_http_conf.sh` + `nginx_https_conf.sh`
- `sample_nginx_http.conf` + `sample_nginx_https.conf`
- `proxy_params/proxy_params`

### 4.2 ngxblocker include 경로 정합화 (4 nginx.conf)

devspoon Dockerfile 은 `install-ngxblocker -c /etc/nginx` (직속 install). 따라서 4 개 nginx.conf 의 include 는:
```nginx
include /etc/nginx/botblocker-nginx-settings.conf;
include /etc/nginx/globalblacklist.conf;
```
(aisum-style `/etc/nginx/ngxblocker.d/` 경로를 쓰지 말 것)

### 4.3 nginx_uvicorn compose 의 마운트 교체

`compose/web-service/nginx_uvicorn/docker-compose.yml` 의 webserver volumes 에서 `nginx/gunicorn/` → `nginx/uvicorn/` 으로 모두 교체 (3 개 마운트).

### 4.4 nginx_uwsgi compose 의 uwsgi_params 마운트

`compose/web-service/nginx_uwsgi/docker-compose.yml` 의 webserver volumes 에서:
```yaml
# 제거
- ../../../config/web-server/nginx/uwsgi/proxy_params/proxy_params:/etc/nginx/proxy_params

# 추가
- ../../../config/web-server/nginx/uwsgi/uwsgi_params/uwsgi_params:/etc/nginx/uwsgi_params
```

### 4.5 commits

```bash
git add config/web-server/nginx/
git commit -m "feat(nginx-conf): sync 3 stacks + add missing nginx_uvicorn stack"

git add compose/web-service/nginx_uvicorn/docker-compose.yml
git commit -m "fix(audit/H1): uvicorn webserver mounts dedicated nginx/uvicorn config dir"

git add compose/web-service/nginx_uwsgi/docker-compose.yml
git commit -m "fix(audit/H2): nginx_uwsgi mounts existing uwsgi_params"
```

## Phase 5 — app-server + scripts + www (30 분)

### 5.1 PHP generator placeholder 복구 (양 버전)

`config/app-server/php-{7.3,8.4}/pool.d/sample_php.conf` 의 첫 줄을 `[domain]` 으로, `listen` 라인을 `listen = [::]:portnumber` 로 변경. `php_conf.sh` 에 `set -euo pipefail` + sed 입력 검증 추가.

### 5.2 logrotate dropin `su root root`

```bash
for f in script/logrotate/*/* script/logrotate/*/*/*; do
  [ -f "$f" ] || continue
  grep -q '^\s*su root root' "$f" || sed -i '/^{/a\    su root root' "$f"
done
```

### 5.3 letsencrypt.sh 대대적 리팩토링

자세한 내용은 `PATCH-003-IMPLEMENTATION.md` §5 참조. 핵심 수정:
- dead dhparam 생성·백업 코드 삭제 (Dockerfile 의 hook 으로 대체됨)
- `/etc/letsencrypt/${array[0]}/letsencrypt` → `/etc/letsencrypt/live/<domain>/`
- `certbot -w /www/$webroot_folder$domain_string` → `-w /www/$webroot_folder` + `-d <domain>`
- `set -eo pipefail` + 입력 regex 검증

### 5.4 test_run 21 개 import + 정합화

aisum-infrakit 의 `script/test_run/*` 16 개를 import 후 ROOT 경로 sed 치환:
```bash
for f in script/test_run/*.sh; do
  sed -i 's|/mnt/c/.*/aisum-infrakit|/mnt/c/Users/rnd15/Documents/project/github/mig/devspoon-web|' "$f"
done
```

추가 정합화 (각 commit 분리):
- `s2_build.sh` 가 `Dockerfile-7.3` / `-8.4` 명시 빌드
- `s1b_nginx_conf_generators.sh`, `s5_https.sh` 의 suffix 오타 (`_http_ng` → `_ng_http`)
- `s2a_image_inspect.sh`, `s3_stack_smoke.sh` 의 stale aisum 파일명 (`aisum-logrotate.sh` 등) → devspoon 실제 파일명

verify_*.sh 5 종 추가 (`PATCH-003` §5 참조).

### 5.5 www 샘플 이전

```bash
cp -r ../aisum-infrakit/www/django_sample  www/
cp -r ../aisum-infrakit/www/fastapi_sample www/
cp -r ../aisum-infrakit/www/flask_sample   www/
cp -r ../aisum-infrakit/www/php_sample     www/
cp -r ../aisum-infrakit/www/certbot        www/
find www -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
find www -type d -name .venv -exec rm -rf {} + 2>/dev/null
```

### 5.6 django_sample pyproject 의 extras 추가

`www/django_sample/pyproject.toml` 에 추가 (Django 4.0.6 호환 위해 daphne 3.x 트랙 핀):
```toml
[project.optional-dependencies]
gunicorn = ["gunicorn>=20"]
uvicorn = ["uvicorn[standard]>=0.30"]
daphne = ["daphne>=3,<4", "channels>=3,<4"]
uwsgi = ["uwsgi>=2.0"]
celery = ["celery>=5", "redis>=5"]
```

이후 `cd www/django_sample && uv lock` 로 lockfile 재생성.

## Phase 6 — README 업데이트 (20 분)

- 영역별 변경 자세히 → `PATCH-003-IMPLEMENTATION.md` §7 의 commits 참조
- 추가할 절 (최소):
  - §0.5.9 — aisum-infrakit 정합화 changelog
  - §3 — dhparam 영속화 절 (build hook + 호스트 백업)
  - §10.3 — script/test_run 사용법
  - §11 — WSL2 운영 가이드
  - Uvicorn / Daphne 설치 절
  - www 샘플 앱 절

## Phase 7 — healthcheck 추가 (15 분)

각 `compose/web-service/<stack>/docker-compose.yml` 에:

```yaml
services:
  webserver:
    depends_on:
      <app-service>:
        condition: service_healthy
      redis:                # Python 스택만, PHP 는 profile: redis 라 제외
        condition: service_healthy
    # ...

  <app-service>:
    healthcheck:
      test: ["CMD-SHELL", "bash -c '</dev/tcp/127.0.0.1/<PORT>' || exit 1"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 30s
    # ...
```

PORT 매핑:
- gunicorn/uvicorn/uwsgi/daphne: 8000
- php-app (7.3, 8.4): 9000

## Phase 8 — 빌드 + 풀스택 검증 (60 분)

### 8.1 이미지 빌드

```bash
docker build -t devspoon-nginx:latest                 docker/nginx/
docker build -t devspoon-py-app:latest                docker/gunicorn/
docker build -t devspoon-uwsgi-app:latest             docker/uwsgi/
docker build -f docker/php-fpm/Dockerfile-7.3 -t devspoon-php-app:7.3 docker/php-fpm/
docker build -f docker/php-fpm/Dockerfile-8.4 -t devspoon-php-app:8.4 docker/php-fpm/
```

### 8.2 단위 검증 (5 verify_*.sh)

`PATCH-004-VERIFICATION.md` §1 의 6 종 verify_*.sh 모두 PASS 확인.

### 8.3 풀스택 통합 (5 스택)

`PATCH-004-VERIFICATION.md` §2.2 의 verify_integration_uvicorn/daphne/uwsgi.sh 실행 + gunicorn/PHP 는 `s3_stack_smoke.sh` 또는 동일 패턴.

## Phase 9 — 종료 조건 확인

`PATCH-004-VERIFICATION.md` §6 의 Exit Criteria 12 개 항목 모두 체크.

## 의사결정 트리 (요약)

```
Phase 0 환경 OK ─ NO → 환경 셋업 먼저
   ↓ YES
Phase 1 명명 통일 ─ 이미 dash? → skip
   ↓
Phase 2 dhparam — 무조건 적용
   ↓
Phase 3 Dockerfile — WSL? → 필수, native? → 적용 무해
   ↓
Phase 4 nginx config — uvicorn 미존재? → 필수
   ↓
Phase 5 app-server + scripts + www — 무조건
   ↓
Phase 6 README — 무조건
   ↓
Phase 7 healthcheck — 무조건 (운영 정합성)
   ↓
Phase 8 빌드 + 검증 — 무조건
   ↓
Phase 9 Exit Criteria — 100% PASS 필요
```
