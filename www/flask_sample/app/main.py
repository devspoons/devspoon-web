"""Flask 진입점 — flask-openapi3 + Scalar UI."""
from __future__ import annotations

from pathlib import Path

import jwt
from flask import Response, jsonify, redirect, request
from flask_openapi3 import Info, OpenAPI, Tag

from app.database import User, db
from app.schemas import (
    ErrorOut,
    MessageOut,
    TokenOut,
    UserCreate,
    UserList,
    UserLogin,
    UserOut,
)
from app.security import (
    ACCESS_TOKEN_EXPIRE_SECONDS,
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)

# ── OpenAPI 메타데이터 (Scalar UI에서 노출) ────────────────────────────────────
info = Info(
    title="Flask Sample",
    version="0.1.0",
    description=(
        "aisum-infrakit 더미 테스트용 Flask 프로젝트.\n\n"
        "- 데이터 저장: 로컬 SQLite\n"
        "- 인증: JWT (HS256)\n"
        "- 문서: `/scalar` 에서 Scalar UI 로 OpenAPI 스키마를 탐색할 수 있다.\n"
        "- OpenAPI JSON: `/openapi/openapi.json`\n"
    ),
)

jwt_scheme = {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}
security_schemes = {"jwt": jwt_scheme}

users_tag = Tag(name="users", description="회원가입 · 로그인 · 본인 계정 관리.")
health_tag = Tag(name="health", description="헬스 체크 및 메타 엔드포인트.")

# 기본 UI(swagger/redoc/rapidoc 등)는 `/openapi/...` 경로로 그대로 두고,
# 우리는 별도의 `/scalar` 엔드포인트에서 Scalar UI 로 동일 스펙을 노출한다.
app = OpenAPI(
    __name__,
    info=info,
    security_schemes=security_schemes,
    doc_ui=True,
    doc_prefix="/openapi",
    doc_url="/openapi.json",
)

DB_PATH = Path(__file__).resolve().parent.parent / "flask_sample.db"
app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{DB_PATH.as_posix()}"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db.init_app(app)

with app.app_context():
    db.create_all()


# ── 인증 유틸 ─────────────────────────────────────────────────────────────────
def _unauthorized(detail: str) -> Response:
    resp = jsonify(ErrorOut(detail=detail).model_dump())
    resp.status_code = 401
    return resp


def _current_user_or_401() -> User | Response:
    auth = request.headers.get("Authorization", "")
    if not auth.lower().startswith("bearer "):
        return _unauthorized("missing bearer token")
    token = auth.split(" ", 1)[1].strip()
    try:
        payload = decode_access_token(token)
    except jwt.ExpiredSignatureError:
        return _unauthorized("token expired")
    except jwt.InvalidTokenError:
        return _unauthorized("invalid token")
    sub = payload.get("sub")
    if sub is None:
        return _unauthorized("invalid token subject")
    user = db.session.get(User, int(sub))
    if user is None:
        return _unauthorized("user no longer exists")
    return user


# ── 라우트 ────────────────────────────────────────────────────────────────────
@app.post(
    "/api/signup",
    tags=[users_tag],
    summary="회원가입",
    description=(
        "이메일, 사용자 이름, 비밀번호로 새 계정을 생성한다.\n"
        "이메일과 사용자 이름은 시스템 전역에서 고유해야 한다."
    ),
    responses={
        "201": UserOut,
        "409": ErrorOut,
    },
)
def signup(body: UserCreate):
    existing = (
        db.session.query(User)
        .filter((User.email == body.email) | (User.username == body.username))
        .first()
    )
    if existing is not None:
        return jsonify(ErrorOut(detail="email or username already registered").model_dump()), 409

    user = User(
        email=body.email,
        username=body.username,
        password_hash=hash_password(body.password),
    )
    db.session.add(user)
    db.session.commit()
    db.session.refresh(user)
    return jsonify(UserOut.model_validate(user).model_dump(mode="json")), 201


@app.post(
    "/api/login",
    tags=[users_tag],
    summary="로그인",
    description="이메일/비밀번호로 인증 후 JWT 액세스 토큰을 발급한다.",
    responses={
        "200": TokenOut,
        "401": ErrorOut,
    },
)
def login(body: UserLogin):
    user = db.session.query(User).filter(User.email == body.email).first()
    if user is None or not verify_password(body.password, user.password_hash):
        return jsonify(ErrorOut(detail="invalid email or password").model_dump()), 401
    token = create_access_token(subject=user.id)
    return jsonify(
        TokenOut(
            access_token=token,
            token_type="bearer",
            expires_in=ACCESS_TOKEN_EXPIRE_SECONDS,
        ).model_dump()
    ), 200


@app.get(
    "/api/me",
    tags=[users_tag],
    summary="내 정보 조회",
    description="Bearer 토큰으로 인증된 사용자의 정보를 반환한다.",
    security=[{"jwt": []}],
    responses={
        "200": UserOut,
        "401": ErrorOut,
    },
)
def read_me():
    result = _current_user_or_401()
    if isinstance(result, Response):
        return result
    return jsonify(UserOut.model_validate(result).model_dump(mode="json")), 200


@app.delete(
    "/api/me",
    tags=[users_tag],
    summary="내 계정 삭제",
    description="현재 로그인된 사용자의 계정을 영구 삭제한다.",
    security=[{"jwt": []}],
    responses={
        "204": None,
        "401": ErrorOut,
    },
)
def delete_me():
    result = _current_user_or_401()
    if isinstance(result, Response):
        return result
    db.session.delete(result)
    db.session.commit()
    return Response(status=204)


@app.get(
    "/api/users",
    tags=[users_tag],
    summary="전체 사용자 목록",
    description="관리/디버깅용 — 모든 사용자를 가입 시간 역순으로 반환한다.",
    responses={"200": UserList},
)
def list_users():
    rows = db.session.query(User).order_by(User.created_at.desc()).all()
    return jsonify([UserOut.model_validate(u).model_dump(mode="json") for u in rows]), 200


@app.get(
    "/health",
    tags=[health_tag],
    summary="헬스 체크",
    description="서버 가동 여부를 단순 확인한다.",
    responses={"200": MessageOut},
)
def health():
    return jsonify(MessageOut(message="ok").model_dump()), 200


# ── Scalar UI ────────────────────────────────────────────────────────────────
SCALAR_HTML = """<!doctype html>
<html>
  <head>
    <title>Flask Sample — API Reference</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
  </head>
  <body>
    <script id="api-reference" data-url="/openapi/openapi.json"></script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  </body>
</html>"""


@app.route("/scalar")
def scalar_ui():
    return Response(SCALAR_HTML, mimetype="text/html")


@app.route("/")
def root():
    return redirect("/scalar")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
