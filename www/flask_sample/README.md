# flask_sample

aisum-infrakit 더미 테스트용 Flask 프로젝트.

## 기능
- 회원가입 / 로그인 (JWT) / 본인 조회 / 본인 삭제
- 로컬 SQLite (`flask_sample.db`)
- `flask-openapi3` 로 자동 생성된 OpenAPI 스키마를 Scalar UI 로 노출

## 실행

```bash
uv sync
uv run flask --app app.main run --host 0.0.0.0 --port 5000
# 또는
uv run python -m app.main
```

- API 문서 (Scalar): http://localhost:5000/scalar
- OpenAPI JSON: http://localhost:5000/openapi/openapi.json
- 헬스 체크: http://localhost:5000/health

## 주요 엔드포인트
| Method | Path | 설명 |
|--------|------|------|
| POST | /api/signup | 회원가입 |
| POST | /api/login  | 로그인, JWT 발급 |
| GET  | /api/me     | 내 정보 (Bearer) |
| DELETE | /api/me   | 내 계정 삭제 (Bearer) |
| GET  | /api/users  | 전체 사용자 목록 |

환경변수 `FLASK_SAMPLE_JWT_SECRET` 로 JWT 시크릿을 덮어쓸 수 있다.
