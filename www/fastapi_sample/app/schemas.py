"""Pydantic 스키마 — OpenAPI/Scalar 문서에 노출되는 표면."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


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
    password: str = Field(..., min_length=8, max_length=128, description="평문 비밀번호. 서버에서 bcrypt로 해시 저장된다.")


class UserLogin(BaseModel):
    """로그인 요청 페이로드 (이메일 + 비밀번호)."""

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
    """응답에서 노출되는 사용자 표현 (비밀번호는 절대 포함되지 않음)."""

    model_config = ConfigDict(from_attributes=True)

    id: int = Field(..., description="사용자 식별자.")
    email: EmailStr = Field(..., description="사용자 이메일.")
    username: str = Field(..., description="표시 이름.")
    created_at: datetime = Field(..., description="가입 시각 (UTC).")


class TokenOut(BaseModel):
    """로그인 성공 시 발급되는 JWT."""

    access_token: str = Field(..., description="HTTP Authorization 헤더에 Bearer 토큰으로 사용.")
    token_type: str = Field("bearer", description="고정값 'bearer'.")
    expires_in: int = Field(..., description="만료까지 남은 초.")


class MessageOut(BaseModel):
    """간단한 메시지 응답."""

    message: str = Field(..., description="사람이 읽을 수 있는 상태 메시지.")


class ErrorOut(BaseModel):
    """오류 응답."""

    detail: str = Field(..., description="오류 상세 메시지.")
