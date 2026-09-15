#!/usr/bin/env bash
# 서버 기동 전 1회 — compose app command 가 Django migrate 다음·서버 exec 전에 `bash prestart.sh` 로 호출한다.
# 로컬: uv run bash prestart.sh
set -euo pipefail
python -c 'from app.main import init_db; init_db()'
