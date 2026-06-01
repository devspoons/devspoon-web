---
patch_id: PATCH-2026-06-01
doc_id: PATCH-002-CONTEXT
title: 의사결정 컨텍스트 — 왜 이 패치인가, 보존 정책, 사용자 결정
parent: 2026-06-01-PATCH-001-INDEX.md
---

# PATCH-2026-06-01-002 컨텍스트

이 문서는 **Claude 가 본 패치를 처음 보았을 때** 의사결정의 "왜" 를 한 페이지로 흡수할 수 있도록 압축한 것입니다. 구현 세부(`PATCH-003`) 와 재현 절차(`PATCH-006`) 보다 먼저 읽어야 다른 패치의 결정도 적절히 응용할 수 있습니다.

## 1. 사용자의 원본 요청 (그대로 인용)

> aisum-infrakit 프로젝트는 devspoon-web 을 기반으로 만들어졌으며, 현재 특정 목적으로 경로가 조금씩 다르게 구성되어 있다. 하지만 하위 폴더의 위치가 줄어든 것일 뿐, 핵심 경로들은 그대로이다. docker-compose 및 많은 설정이 변경되었으며 스크립트 파일들의 내용이 크게 달라졌다. devspoon-web의 내용을 aisum-infrakit 프로젝트를 기준으로 동일하게 업데이트를 해줘. 이후 변경된 사항들에 대해 devspoon-web 프로젝트에서의 폴더 및 파일 위치 및 사용 방법에 대해서 readme에 최신 업데이트를 반영 해줘. 모든 작업이 종료되면 wsl를 사용하여 모든 컨테이너들의 동자과 설정 파일들의 동작, 스크립트의 동작을 검토해줘. 모든 테스트는 aisum-infrakit의 www에 있는 폴더들을 devspoon-web의 www에 옮기고 이 곳에 복사되는 적절한 샘플과 docker-compose의 목적에 맞게 app 및 web의 nginx 설정을 내부 스크립트를 이용해 구축해줘. 도메인이 없기 때문에 https의 cerbot 테스트는 제외해줘. 하지만 docker 컨테이너의 build로 보안키가 제대로 생성이 되고 백업이 되는지, 이후 docker compose down을 하더라도 먼저 백업된 키를 확인하여 복구를 시도하는지, nginx의 https 샘플 파일은 제대로 생성이 되는지, 경로 설정이 맞게 되는지에 대해서만 https 관련 테스트를 진행해줘

## 2. 두 프로젝트의 관계

```
devspoon-web (open-source 원본)
   └─ fork: aisum-infrakit (사내 표준화 + 단순화)
         └─ 운영하면서 검증 산출물 누적
            └─ 다시 devspoon-web 으로 역머지 ← 이 패치
```

- **devspoon-web** — open source. PHP 7.3/8.4 두 버전, nginx_daphne 스택 보존, docs/operations-guide/ 풍부, `entrypoint-with-cron.sh` 별도 파일 패턴
- **aisum-infrakit** — 사내 fork. 단일 PHP 7.2, daphne 없음, docs 없음, Dockerfile 인라인 cron, 운영 검증 자산(test_run 16개, dhparam 영속화 메커니즘) 누적

핵심: aisum 은 **함축적이고 검증된 신호**, devspoon-web 은 **풍부한 표면과 다양성**. 역머지 시 신호는 흡수하되 다양성은 보존.

## 3. 보존 정책 — 절대로 건드리지 말 것

다음은 devspoon-web 만의 자산이며 aisum 에는 없거나 다르게 처리되지만 **반드시 유지**:

| 보존 대상 | 이유 |
|---|---|
| `compose/web-service/nginx_daphne/` 스택 | devspoon 고유 ASGI WebSocket 스택. aisum 미보유 |
| `compose/web-service/nginx_php-7.3/` + `nginx_php-8.4/` 두 PHP 버전 | aisum 은 단일 PHP 7.2. devspoon 은 legacy + current 동시 지원이 의도된 design |
| `config/app-server/php-7.3/` + `php-8.4/` 분리 | 위와 같은 이유. php.ini 의 8.x 호환 패치는 8.4 폴더에만 적용 |
| `docker/{gunicorn,uwsgi,php-fpm}/entrypoint-with-cron.sh` 3개 | aisum 은 Dockerfile RUN 인라인 패턴. devspoon 은 별도 파일이 더 명확하고 cron + logrotate sanitize 로직을 모듈화하기 좋음 |
| `docker/php-fpm/Dockerfile-7.3` + `Dockerfile-8.4` 두 변형 | PHP 버전별 베이스 이미지 차이 (`romeoz/docker-phpfpm:7.3` vs `php:8.4-fpm-bookworm`) |
| `docs/operations-guide/nginx-hardening/*` 6 문서 | devspoon 의 운영 가이드 자산. aisum 미보유 |
| `redis.conf` 의 `protected-mode yes` | aisum 은 `no`. devspoon 정책이 우월 — 인증 강제 |
| `CELERY_BROKER_URL` 의 compose 합성 (SSOT) | aisum 은 .env 에 별도 보관. devspoon 은 `REDIS_PASSWORD` 로부터 합성하여 drift 차단 |
| `script/letsencrypt.sh` | devspoon 버전이 더 진화된 상태. aisum 버전으로 덮어쓰지 말 것 |
| `script/logrotate/daphne/*` 3개 | daphne 스택 보존과 짝 |

## 4. 사용자 결정 사항 (브레인스토밍 단계에서 결정됨)

3개 핵심 질문에 사용자가 다음과 같이 답:

### 결정 1 — 기존 요소 처리
> "devspoon-web에 있지만 aisum-infrakit에 없는 요소들(nginx_daphne, php-7.3/8.4 두 버전, docs/, entrypoint-with-cron.sh)을 어떻게 처리할까요?"
- ✅ **기존 유지 + aisum 개선사항 추가** (위 §3 보존 정책의 근거)

### 결정 2 — 명명 규칙
> "디렉토리·파일 명명 규칙은 어느 쪽을 따를까요?"
- ✅ **aisum-infrakit 규칙 따르기** — `compose/web-service/` (dash), `.env-example` (dash)
- devspoon 의 기존 `compose/web_service/` (underscore), `.env.example` (dot) 은 모두 변경

### 결정 3 — 커밋 전략
> "변경사항을 git 커밋으로 분리할까요?"
- ✅ **기능별로 다수 atomic commit** — 한 commit = 한 가지 변경 + 명확한 이유 + Co-Authored-By

## 5. HTTPS 검증 범위 (사용자가 명시적으로 제한)

| 검증 항목 | 포함 / 제외 |
|---|---|
| docker build 시 보안키 생성 | ✅ 포함 |
| 키 호스트 백업 동작 | ✅ 포함 |
| docker compose down → up 후 백업 복구 시도 | ✅ 포함 |
| nginx HTTPS 샘플 파일 생성 | ✅ 포함 |
| 경로 설정 정합성 | ✅ 포함 |
| **certbot Let's Encrypt 실발급** | ❌ **제외** (도메인 없음) |

이 제약 때문에 `script/letsencrypt.sh` 의 실제 호출 path 는 코드 리뷰로만 검증하고, dhparam 의 build/backup/restore 와 sample 생성기는 풀스택 컨테이너로 검증.

## 6. 사용자가 결정한 추가 권고사항 (Agent F 라운드 2)

| 권고 | 처리 결과 |
|---|---|
| app healthcheck 보강 | ✅ 라운드 3 에서 6 스택 모두 `/dev/tcp` healthcheck + service_healthy depends_on 적용 (`bf8b6c4`) |
| WSL 운영 가이드 | ✅ 라운드 3 에서 README §11 신설 (`af0e98c`) |
| daphne 4.x 업그레이드 로드맵 | ⏭ 보고만 — 별도 PR 권장 (현재 3.x 트랙 핀, Django 4.0 호환) |
| uvicorn/uwsgi/daphne 동일 통합 테스트 | ✅ 라운드 3 에서 모두 풀스택 검증 (`6a4df02`). 단 uwsgi 는 Django 500 (별도 issue) |

## 7. Claude 가 본 패치를 다른 시점에 적용할 때 반드시 확인할 것

1. **타겟 저장소가 정말 devspoon-web fork 패밀리인가?** — 그렇지 않다면 보존 정책이 다를 수 있음
2. **이미 patch 가 일부 적용됐는가?** — `compose/web-service/` (dash) 가 이미 있다면 §3 명명 규칙 단계 skip
3. **WSL 환경인가, Linux native 인가?** — `script/logrotate/*` 의 `su root root` 와 `entrypoint-with-cron.sh` 의 0644 sanitize 는 WSL 0777 마운트 회피용. Linux native 에선 무해하지만 불필요
4. **PHP 버전 정책이 같은가?** — 다른 fork 가 PHP 8.4 단일이라면 php-7.3 변형 코드는 적용하지 말 것
5. **Python 3.14 / nginx 1.27 등 베이스 이미지 핀** — fork 의 정책 우선

## 8. 본 문서를 읽었다면 다음에 읽을 것

- 구현 세부 → `PATCH-003-IMPLEMENTATION.md`
- 검증 절차 → `PATCH-004-VERIFICATION.md`
- 다른 환경 재적용 → `PATCH-006-RUNBOOK.md`
- Claude 학습 데이터 → `PATCH-007-CLAUDE-PROMPT.md`
