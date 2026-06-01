"""사용자 관련 라우터 — 회원가입, 로그인, 본인 조회/삭제."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import (
    ErrorOut,
    MessageOut,
    TokenOut,
    UserCreate,
    UserLogin,
    UserOut,
)
from app.security import (
    ACCESS_TOKEN_EXPIRE_SECONDS,
    create_access_token,
    hash_password,
    verify_password,
)

router = APIRouter(prefix="/api", tags=["users"])


@router.post(
    "/signup",
    response_model=UserOut,
    status_code=status.HTTP_201_CREATED,
    summary="회원가입",
    description=(
        "이메일, 사용자 이름, 비밀번호로 새로운 계정을 생성한다.\n\n"
        "- 이메일과 사용자 이름은 시스템 전역에서 고유해야 한다.\n"
        "- 비밀번호는 서버에서 bcrypt로 해시되어 저장된다."
    ),
    responses={
        201: {"description": "사용자가 정상적으로 생성됨", "model": UserOut},
        409: {"description": "이메일 또는 사용자 이름 중복", "model": ErrorOut},
    },
)
def signup(payload: UserCreate, db: Session = Depends(get_db)) -> User:
    existing = db.execute(
        select(User).where((User.email == payload.email) | (User.username == payload.username))
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="email or username already registered",
        )

    user = User(
        email=payload.email,
        username=payload.username,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post(
    "/login",
    response_model=TokenOut,
    summary="로그인",
    description="이메일과 비밀번호로 인증하고 JWT 액세스 토큰을 발급한다.",
    responses={
        200: {"description": "인증 성공, JWT 발급", "model": TokenOut},
        401: {"description": "이메일이 존재하지 않거나 비밀번호 불일치", "model": ErrorOut},
    },
)
def login(payload: UserLogin, db: Session = Depends(get_db)) -> TokenOut:
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid email or password",
        )
    token = create_access_token(subject=user.id)
    return TokenOut(access_token=token, token_type="bearer", expires_in=ACCESS_TOKEN_EXPIRE_SECONDS)


@router.get(
    "/me",
    response_model=UserOut,
    summary="내 정보 조회",
    description="Bearer 토큰으로 인증된 사용자의 정보를 반환한다.",
    responses={
        200: {"description": "현재 로그인 사용자", "model": UserOut},
        401: {"description": "토큰 누락/만료/위변조", "model": ErrorOut},
    },
)
def read_me(current_user: User = Depends(get_current_user)) -> User:
    return current_user


@router.delete(
    "/me",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="내 계정 삭제",
    description="현재 로그인된 사용자의 계정을 영구 삭제한다.",
    responses={
        204: {"description": "삭제 성공, 응답 본문 없음"},
        401: {"description": "인증 실패", "model": ErrorOut},
    },
)
def delete_me(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    db.delete(current_user)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/users",
    response_model=list[UserOut],
    summary="전체 사용자 목록",
    description="관리/디버깅용 — 모든 사용자를 가입 시간 역순으로 반환한다.",
)
def list_users(db: Session = Depends(get_db)) -> list[User]:
    rows = db.execute(select(User).order_by(User.created_at.desc())).scalars().all()
    return list(rows)
