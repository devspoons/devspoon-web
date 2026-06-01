# fastapi_sample

aisum-infrakit 더미 테스트용 FastAPI 프로젝트.

## 기능
- 회원가입 / 로그인 (JWT) / 본인 조회 / 본인 삭제
- 로컬 SQLite (`fastapi_sample.db`)
- `scalar-fastapi` 로 Scalar UI 형태의 OpenAPI 문서 제공

## 실행

```bash
uv sync
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- API 문서 (Scalar): http://localhost:8000/scalar
- OpenAPI JSON: http://localhost:8000/openapi.json
- 헬스 체크: http://localhost:8000/health

## 주요 엔드포인트
| Method | Path | 설명 |
|--------|------|------|
| POST | /api/signup | 회원가입 |
| POST | /api/login  | 로그인, JWT 발급 |
| GET  | /api/me     | 내 정보 (Bearer) |
| DELETE | /api/me   | 내 계정 삭제 (Bearer) |
| GET  | /api/users  | 전체 사용자 목록 |

환경변수 `FASTAPI_SAMPLE_JWT_SECRET` 로 JWT 시크릿을 덮어쓸 수 있다.
