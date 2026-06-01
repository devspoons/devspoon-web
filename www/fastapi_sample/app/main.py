"""FastAPI 진입점 — Scalar UI로 OpenAPI 문서를 노출한다."""
from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from scalar_fastapi import get_scalar_api_reference

from app.database import init_db
from app.routers import users
from app.schemas import MessageOut


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="FastAPI Sample",
    version="0.1.0",
    summary="회원가입 / 로그인 / 계정 삭제 데모 REST API.",
    description=(
        "이 서비스는 aisum-infrakit 더미 테스트용 FastAPI 프로젝트다.\n\n"
        "- 데이터 저장: 로컬 SQLite\n"
        "- 인증: JWT (HS256)\n"
        "- 문서: `/scalar` 에서 Scalar UI 로 OpenAPI 스키마를 탐색할 수 있다.\n"
        "- OpenAPI JSON: `/openapi.json`\n"
    ),
    openapi_tags=[
        {"name": "users", "description": "회원가입 · 로그인 · 본인 계정 관리."},
        {"name": "health", "description": "헬스 체크 및 메타 엔드포인트."},
    ],
    docs_url=None,  # Swagger UI 비활성화 — Scalar UI 만 노출
    redoc_url=None,
    lifespan=lifespan,
)


app.include_router(users.router)


@app.get(
    "/",
    response_class=RedirectResponse,
    include_in_schema=False,
)
def root() -> RedirectResponse:
    return RedirectResponse(url="/scalar")


@app.get(
    "/scalar",
    include_in_schema=False,
)
def scalar_html():
    return get_scalar_api_reference(
        openapi_url=app.openapi_url,
        title=f"{app.title} — API Reference",
    )


@app.get(
    "/health",
    response_model=MessageOut,
    tags=["health"],
    summary="헬스 체크",
    description="서버 가동 여부를 단순 확인한다.",
)
def health() -> MessageOut:
    return MessageOut(message="ok")
