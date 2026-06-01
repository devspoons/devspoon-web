"""Pydantic 스키마 — flask-openapi3가 OpenAPI 문서로 변환한다."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, RootModel


class UserCreate(BaseModel):
    """회원가입 요청 페이로드."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "email": "alice@example.com",
                    "username": "alice",
                    "password": "S3cret!pass",
                }
            ]
        }
    )

    email: EmailStr = Field(..., description="중복 불가능한 사용자 이메일.")
    username: str = Field(..., min_length=3, max_length=64, description="3~64자의 표시 이름.")
    password: str = Field(..., min_length=8, max_length=128, description="평문 비밀번호. bcrypt로 해시 저장된다.")


class UserLogin(BaseModel):
    """로그인 요청 페이로드."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {"email": "alice@example.com", "password": "S3cret!pass"}
            ]
        }
    )

    email: EmailStr = Field(..., description="가입 시 사용한 이메일.")
    password: str = Field(..., description="평문 비밀번호.")


class UserOut(BaseModel):
    """비밀번호를 제외한 사용자 표현."""

    model_config = ConfigDict(from_attributes=True)

    id: int = Field(..., description="사용자 식별자.")
    email: EmailStr = Field(..., description="사용자 이메일.")
    username: str = Field(..., description="표시 이름.")
    created_at: datetime = Field(..., description="가입 시각 (UTC).")


class TokenOut(BaseModel):
    """JWT 발급 응답."""

    access_token: str = Field(..., description="HTTP Authorization 헤더의 Bearer 토큰으로 사용.")
    token_type: str = Field("bearer", description="고정값 'bearer'.")
    expires_in: int = Field(..., description="만료까지 남은 초.")


class MessageOut(BaseModel):
    """간단한 메시지 응답."""

    message: str = Field(..., description="사람이 읽을 수 있는 상태 메시지.")


class ErrorOut(BaseModel):
    """오류 응답."""

    detail: str = Field(..., description="오류 상세 메시지.")


class UserList(RootModel[list[UserOut]]):
    """사용자 목록 응답 (배열 루트)."""

    model_config = ConfigDict(
        json_schema_extra={"description": "사용자 목록 — UserOut 의 배열."}
    )
