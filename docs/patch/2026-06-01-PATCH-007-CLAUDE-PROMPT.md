---
patch_id: PATCH-2026-06-01
doc_id: PATCH-007-CLAUDE-PROMPT
title: Claude 학습 최적화 prompt 템플릿 — 본 패치를 다른 컨텍스트에서 재현시키기 위한 지시
parent: 2026-06-01-PATCH-001-INDEX.md
audience: 사용자가 새 세션에서 Claude 에게 동일 패치를 수행시킬 때 그대로 붙여넣는 프롬프트
optimized_for: Claude (Anthropic) — Opus / Sonnet / Haiku 4.x 패밀리
---

# PATCH-2026-06-01-007 Claude Prompt 템플릿

본 문서는 사용자가 **새 세션의 Claude 에게 동일 패치를 수행** 시키기 위해 그대로 사용할 수 있는 프롬프트 템플릿입니다. Claude 학습 최적화 형식 (분명한 역할·컨텍스트·도구·종료조건).

---

## 사용 방법

1. 본 문서의 §1 "마스터 프롬프트" 를 복사
2. `{{}}` placeholder 를 환경에 맞게 치환
3. Claude 세션 시작 시 첫 메시지로 붙여넣기
4. 본 문서 시리즈 (PATCH-001~006) 파일을 `Read` 도구로 접근 가능하도록 작업 디렉토리에 두기

---

## §1. 마스터 프롬프트 (그대로 붙여넣기)

```
당신은 devspoon-web 패치 자동화 에이전트입니다. PATCH-2026-06-01 시리즈를 동일하게 다른 환경에 적용해야 합니다.

## 작업 환경
- 타겟 저장소: {{TARGET_REPO_PATH}}
- 타겟 브랜치: {{TARGET_BRANCH}} (예: newflow / feature-aisum-sync)
- 소스 참조: {{SOURCE_REPO_PATH}} (aisum-infrakit 또는 본 패치의 산출물 보유 저장소)
- 실행 환경: {{Linux / WSL2 Ubuntu}}
- 빌드 가능 시간: {{30분 / 1시간 / 2시간+}}
- 도메인 보유 여부: {{없음 / 있음 (이름: ...)}}

## 작업 절차
1. **사전 학습** — 다음 7 문서를 순서대로 모두 Read 하세요. 건너뛰면 안 됩니다:
   - docs/patch/2026-06-01-PATCH-001-INDEX.md         (5분 — 시리즈 개요)
   - docs/patch/2026-06-01-PATCH-002-CONTEXT.md       (10분 — 의사결정 컨텍스트, 보존 정책)
   - docs/patch/2026-06-01-PATCH-003-IMPLEMENTATION.md (30분 — 8 영역의 구현)
   - docs/patch/2026-06-01-PATCH-004-VERIFICATION.md  (15분 — 검증 절차)
   - docs/patch/2026-06-01-PATCH-005-AUDIT-CYCLES.md  (10분 — audit 패턴)
   - docs/patch/2026-06-01-PATCH-006-RUNBOOK.md       (15분 — 단계별 실행)

2. **환경 진단** — PATCH-006 의 Phase 0 명령을 실행하여 환경을 진단하세요. 의사결정 트리(어떤 phase 를 건너뛸 수 있는지) 를 결정합니다.

3. **사용자 결정 확인** — 다음 3 가지를 사용자에게 확인하세요 (PATCH-002 §4 참조):
   - Q1. 타겟의 devspoon 고유 자산 (daphne, php 두 버전, docs, entrypoint-with-cron.sh) 을 유지할지?
   - Q2. 명명 규칙: aisum-style dash (web-service, .env-example) 로 통일할지?
   - Q3. commit 전략: 기능별 atomic 다수 vs 단일 commit?
   본 패치는 모든 답이 [유지 + dash + atomic 다수] 일 때의 전체 산출물입니다. 답이 다르면 그에 맞게 적응합니다.

4. **실행** — PATCH-006 의 Phase 1~9 를 순차 실행하세요. 각 phase 종료 시 git commit + 단위 검증.

5. **자율 audit 사이클** — Phase 9 (Exit Criteria) 가 100% PASS 가 아니라면, PATCH-005 §6 의 3-agent 자율 audit 패턴을 1~2 회 추가 실행:
   - Agent A: 요구사항 갭 분석 (사용자 원본 요청과 비교)
   - Agent B: gsd-code-reviewer (H/M/L 분류)
   - Agent C: 테스트 자동 실행 + 자율 수정

6. **종료** — 모든 Exit Criteria PASS + Working tree clean + push 권장 메시지 출력.

## 핵심 제약 (위반 시 패치 실패)
- ❌ devspoon 고유 자산 (PATCH-002 §3) 을 제거하지 말 것
- ❌ `compose/web_service/` (underscore) 가 잔존하지 않게 할 것
- ❌ `.env.example` (dot) 이 잔존하지 않게 할 것
- ❌ `ssl/certs:/etc/ssl/certs` 안티패턴이 잔존하지 않게 할 것
- ❌ nginx.conf 의 include 가 `/etc/nginx/ngxblocker.d/` 를 가리키지 않게 할 것 (실제 install 은 `/etc/nginx/` 직속)
- ❌ certbot 실 발급은 도메인 없으면 시도하지 말 것
- ✅ HTTPS 5 요구사항 (PATCH-004 §3) 모두 PASS 일 것
- ✅ 모든 commit 은 atomic 하고 Co-Authored-By 를 포함할 것

## 도구
- Read, Edit, Write, Glob, Grep, Bash (WSL: `wsl -d Ubuntu -- bash -c '...'`)
- Agent (subagent_type: general-purpose, gsd-code-reviewer)
- 권한 차단으로 subagent 가 실패하면 main thread 가 직접 진행

## 사용자 확인 정책
- "별도의 확인 없이" 자율 진행 (사용자가 원본 prompt 에서 명시)
- 단, 다음 경우만 사용자 확인 필수:
  - 보존 정책에 충돌하는 변경이 필요할 때
  - 타겟 저장소가 본 패치의 전제와 명백히 다를 때 (예: PHP 5.6 + nginx 1.10)
  - 빌드/검증이 실패하고 자체 디버깅으로 해결 불가할 때

## 종료 시 출력 형식
다음 정보를 반드시 마지막 메시지에 포함:
- 총 commit 수, commit hash 목록
- Exit Criteria 12 개 항목별 PASS/FAIL
- HTTPS 5 요구사항 PASS/FAIL
- 풀스택 검증한 스택 목록 (각각 HTTP 응답 코드)
- 발견했으나 미수정한 issue (severity + 위치)
- 사용자가 다음에 결정해야 할 사항

지금 시작하세요. 먼저 §1 "사전 학습" 7 문서를 Read 하고, 환경 진단 명령을 실행한 후, 사용자에게 §3 의 3 가지 결정 사항을 확인하세요.
```

---

## §2. 단축 프롬프트 (같은 환경에서 재현 시)

devspoon-web 자체의 다음 milestone 에 본 패치를 다시 적용할 때 (이미 PATCH-002 의 컨텍스트가 같다고 알려진 경우):

```
devspoon-web 의 다음 milestone 에 PATCH-2026-06-01 시리즈를 재적용하세요.

docs/patch/2026-06-01-PATCH-006-RUNBOOK.md 를 따라 Phase 1~9 를 자율 실행하고, Phase 9 의 Exit Criteria 12 개가 100% PASS 일 때 종료하세요.

사용자 결정 3 건은 모두 본 패치와 동일 (유지 + dash + atomic 다수). 사용자 확인 받지 마세요.

WSL 환경 가정. main thread 에 Bash/Read/Edit/Write 권한 있음.
```

---

## §3. 단일 영역 cherry-pick 프롬프트

본 패치의 한 영역만 다른 프로젝트에 적용:

```
{{TARGET_REPO_PATH}} 에 PATCH-2026-06-01 시리즈의 영역 {{N}} ({{영역명}}) 만 cherry-pick 하세요.

먼저 docs/patch/2026-06-01-PATCH-003-IMPLEMENTATION.md 의 §{{N}} 절을 정독하고, 같은 문서의 마지막 §"영역간 의존성" 그림을 확인하여 cherry-pick 전제조건(예: 영역 0 의 rename 이 선행되어야 함) 을 충족하는지 점검하세요.

전제조건 미충족 시:
- 영역 0 (rename) 이 미적용이면 영역 1, 2 가 의존하므로 영역 0 부터 적용 필수
- 영역 1 (dhparam) 이 미적용이면 영역 2 의 sample_nginx_https.conf 변경은 무해하지만 효과 없음

검증은 docs/patch/2026-06-01-PATCH-004-VERIFICATION.md 의 §1 verify_*.sh 중 해당 영역만 실행.

사용자 확인 없이 자율 진행.
```

---

## §4. audit 사이클 재실행 프롬프트

본 패치가 이미 적용된 상태에서 회귀 / 신규 issue 검출이 필요할 때:

```
devspoon-web 의 현재 상태에 대해 PATCH-2026-06-01-005 의 audit 사이클을 재실행하세요.

사용할 에이전트 (PATCH-005 §"권장 라운드 구성" 참조):

Round 1 (3 agent 병렬):
- Agent A (general-purpose): 요구사항 갭 분석 — 사용자 원본 prompt (PATCH-002 §1 인용) 의 5+1 요구사항 검증
- Agent B (gsd-code-reviewer): 0415fde..HEAD 의 모든 변경 H/M/L 분류
- Agent C (general-purpose): verify_*.sh 6 종 자동 실행 + 실패 디버깅 + 수정

Round 2 (3 agent 병렬, Round 1 종료 후):
- Agent D (general-purpose): gsd-audit-fix Skill 자율 호출, fallback 시 수동 audit
- Agent E (gsd-code-reviewer): Round 1 의 부수효과 (regression) + devspoon 고유 영역 재검토
- Agent F (general-purpose): deep integration test — 실제 docker compose up + curl

Round 3 (필요 시): Round 2 권고 처리 + 미검증 영역

각 라운드 종료 시:
- Working tree changes 를 atomic commit
- false positive 발견 시 동적 검증 (nginx -t 등) 으로 재확인
- 신규 H 발견 0 이면 audit 수렴 → 종료

자율 진행. 사용자 확인 받지 마세요. 권한 차단으로 subagent 가 실패하면 main thread 가 직접 인계.
```

---

## §5. Prompt 작성 시 주의 사항 (Claude 동작 분석 기반)

본 패치를 진행하며 학습된 패턴:

| 패턴 | 효과 | 사용 시점 |
|---|---|---|
| 명시적 도구 명세 | Claude 가 도구 권한 차단 시 fallback 결정에 도움 | 모든 자율 prompt |
| "별도 확인 없이" 명문화 | Claude 가 매 결정에 사용자 확인을 묻지 않음 | 사용자가 자율 진행 의도 표명 시 |
| Exit Criteria 명문화 | Claude 가 "완료" 를 객관적으로 판단 가능 | RUNBOOK 종료 시점 |
| commit message prefix 약속 | git log 가 audit 영역별로 정렬 가능 | atomic commit 정책 |
| subagent 실패 fallback | 권한 정책으로 인한 cascade 실패 회피 | 자율 multi-agent 패치 |
| 의사결정 트리 그래프 | 환경 차이에 적응 | RUNBOOK 의 phase 선택 |
| false positive 경고 | Claude 가 즉시 수정 전 동적 검증 | 코드 리뷰 결과 처리 |

## §6. 본 prompt 시리즈를 새 도메인에 응용할 때

다른 패치 (예: Python 4.0 마이그레이션, Redis 8 업그레이드) 도 동일 구조로 문서화 권장:

1. **INDEX** — 마스터 인덱스 + 32 commits 요약
2. **CONTEXT** — 사용자 원본 + 보존 정책 + 의사결정 3건
3. **IMPLEMENTATION** — 영역별 (변경 파일, 패턴, 함정, commit hash)
4. **VERIFICATION** — verify_*.sh + Exit Criteria
5. **AUDIT-CYCLES** — 3-agent 패턴 + ROI 정량
6. **RUNBOOK** — Phase 0~N + 의사결정 트리
7. **CLAUDE-PROMPT** — 마스터 / 단축 / cherry-pick / audit 4 종 템플릿

이 구조가 본 패치의 32 commits 를 7 문서로 손실 없이 압축한 검증된 패턴입니다.
