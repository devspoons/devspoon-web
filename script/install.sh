#!/usr/bin/env bash
# =============================================================================
# aisum-infrakit 호스트 의존성 설치 스크립트 (Ubuntu 24.04 기준)
# -----------------------------------------------------------------------------
# 설치 대상: docker(engine) · docker compose(plugin v2) · uv · vim
#
# 동작:
#   - 현재 계정이 root 면 sudo 없이 그대로 실행한다.
#   - root 가 아니면 sudo 비밀번호를 한 번 입력받아 내부 변수($SUDO_PASS)에 저장하고,
#     백그라운드 keepalive 로 sudo 인증을 유지하며 설치를 진행한다.
#   - 이미 설치된 항목은 건너뛴다(idempotent). 재실행해도 안전하다.
#
# 사용법:
#   chmod +x script/install.sh
#   ./script/install.sh
# =============================================================================
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ----- 로그 헬퍼 -------------------------------------------------------------
c_info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
c_ok()    { printf '\033[1;32m[ OK ]\033[0m  %s\n' "$*"; }
c_warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
c_err()   { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*" >&2; }
die()     { c_err "$*"; exit 1; }

# ----- OS 확인 (Ubuntu 24.04 권장) -------------------------------------------
if [ -r /etc/os-release ]; then
    . /etc/os-release
    if [ "${ID:-}" != "ubuntu" ]; then
        c_warn "이 스크립트는 Ubuntu 24.04 기준입니다 (감지된 OS: ${PRETTY_NAME:-unknown}). 계속 진행합니다."
    elif [ "${VERSION_ID:-}" != "24.04" ]; then
        c_warn "Ubuntu ${VERSION_ID:-?} 감지됨 (권장: 24.04). 계속 진행합니다."
    fi
else
    c_warn "/etc/os-release 를 읽을 수 없습니다. 계속 진행합니다."
fi

# =============================================================================
# 1) 계정 상태 확인 → root 여부에 따라 sudo 사용 방식 결정
# =============================================================================
SUDO_PASS=""              # sudo 비밀번호를 저장할 내부 변수
KEEPALIVE_PID=""

if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT=1
    c_info "root 계정으로 실행 중 → sudo 없이 설치합니다."
else
    IS_ROOT=0
    c_info "일반 계정($(id -un))으로 실행 중 → sudo 비밀번호가 필요합니다."

    command -v sudo >/dev/null 2>&1 || die "sudo 가 설치되어 있지 않습니다. root 로 실행하거나 sudo 를 먼저 설치하세요."

    # 비밀번호 입력(에코 off) → 내부 변수에 저장
    read -rsp "[sudo] $(id -un) 의 비밀번호: " SUDO_PASS
    echo
    [ -n "$SUDO_PASS" ] || die "비밀번호가 비어 있습니다."

    # 입력한 비밀번호 검증 (sudo 타임스탬프 갱신)
    if ! echo "$SUDO_PASS" | sudo -S -p '' -v 2>/dev/null; then
        die "sudo 비밀번호가 올바르지 않거나 sudo 권한이 없습니다."
    fi
    c_ok "sudo 인증 성공."

    # 설치가 길어져도 재입력 없도록 백그라운드에서 sudo 타임스탬프를 주기적으로 갱신
    ( while true; do
          echo "$SUDO_PASS" | sudo -S -p '' -v 2>/dev/null || exit
          sleep 50
          kill -0 "$$" 2>/dev/null || exit   # 부모(설치 스크립트)가 끝나면 함께 종료
      done ) &
    KEEPALIVE_PID=$!
fi

# 종료 시 keepalive 정리 + sudo 타임스탬프 폐기
cleanup() {
    [ -n "$KEEPALIVE_PID" ] && kill "$KEEPALIVE_PID" 2>/dev/null || true
    [ "$IS_ROOT" -eq 0 ] && sudo -K 2>/dev/null || true
}
trap cleanup EXIT

# root 면 그대로, 아니면 sudo 로 실행하는 래퍼 (sudo 인증은 위 keepalive 가 유지)
as_root() {
    if [ "$IS_ROOT" -eq 1 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# 설치 대상 일반 사용자 (docker 그룹 추가용). sudo 로 호출됐다면 SUDO_USER 사용.
TARGET_USER="${SUDO_USER:-$(id -un)}"

# =============================================================================
# 2) 공통 사전 패키지
# =============================================================================
install_prereqs() {
    c_info "기본 패키지 갱신 및 사전 의존성 설치..."
    as_root apt-get update -y
    as_root apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release
    c_ok "사전 의존성 설치 완료."
}

# =============================================================================
# 3) vim
# =============================================================================
install_vim() {
    if command -v vim >/dev/null 2>&1; then
        c_ok "vim 이미 설치됨 ($(vim --version | head -n1))."
        return
    fi
    c_info "vim 설치..."
    as_root apt-get install -y --no-install-recommends vim
    c_ok "vim 설치 완료."
}

# =============================================================================
# 4) docker engine + docker compose plugin (공식 저장소)
# =============================================================================
install_docker() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        c_ok "docker + compose plugin 이미 설치됨 ($(docker --version))."
        return
    fi

    c_info "Docker 공식 GPG 키 및 apt 저장소 등록..."
    as_root install -m 0755 -d /etc/apt/keyrings
    # 키가 이미 있으면 덮어쓰기 위해 --batch 없이 직접 내려받아 배치
    as_root curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    as_root chmod a+r /etc/apt/keyrings/docker.asc

    local arch codename
    arch="$(dpkg --print-architecture)"
    codename="$( . /etc/os-release && echo "${VERSION_CODENAME:-noble}" )"

    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
        | as_root tee /etc/apt/sources.list.d/docker.list >/dev/null

    c_info "Docker 패키지 설치 (engine · cli · containerd · buildx · compose plugin)..."
    as_root apt-get update -y
    as_root apt-get install -y \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 서비스 활성화 (systemd 가 있는 환경에서만)
    if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
        as_root systemctl enable --now docker 2>/dev/null \
            && c_ok "docker 서비스 활성화 완료." \
            || c_warn "docker 서비스 자동 시작에 실패했습니다 (WSL 등 systemd 비활성 환경일 수 있음)."
    else
        c_warn "systemctl 미존재 → docker 서비스는 수동으로 시작해야 할 수 있습니다 (예: 'sudo service docker start')."
    fi

    # 일반 사용자를 docker 그룹에 추가 (sudo 없이 docker 사용 — 재로그인 필요)
    if [ "$IS_ROOT" -eq 0 ] || [ -n "${SUDO_USER:-}" ]; then
        if ! id -nG "$TARGET_USER" 2>/dev/null | grep -qw docker; then
            as_root usermod -aG docker "$TARGET_USER" \
                && c_warn "'$TARGET_USER' 를 docker 그룹에 추가했습니다. 적용하려면 재로그인(또는 'newgrp docker')하세요."
        fi
    fi

    c_ok "docker 설치 완료 ($(docker --version))."
}

# =============================================================================
# 5) uv (Astral 공식 설치 스크립트) — /usr/local/bin 에 설치하여 전역 사용
# =============================================================================
install_uv() {
    if command -v uv >/dev/null 2>&1; then
        c_ok "uv 이미 설치됨 ($(uv --version))."
        return
    fi
    c_info "uv 설치 (/usr/local/bin)..."
    # 공식 설치 스크립트를 root 권한으로 실행하되, 설치 경로를 /usr/local/bin 으로 지정.
    # INSTALLER_NO_MODIFY_PATH=1: 이미 PATH 에 있는 디렉토리이므로 셸 설정 파일을 건드리지 않음.
    curl -LsSf https://astral.sh/uv/install.sh \
        | as_root env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh
    hash -r 2>/dev/null || true
    if command -v uv >/dev/null 2>&1; then
        c_ok "uv 설치 완료 ($(uv --version))."
    else
        c_warn "uv 설치는 끝났지만 현재 셸 PATH 에서 즉시 인식되지 않습니다. 새 셸을 열거나 'export PATH=/usr/local/bin:\$PATH'."
    fi
}

# =============================================================================
# 실행
# =============================================================================
c_info "===== aisum-infrakit 의존성 설치 시작 ====="
install_prereqs
install_vim
install_docker
install_uv

echo
c_ok "===== 설치 완료 ====="
printf '  %-16s %s\n' "docker:"  "$(command -v docker  >/dev/null 2>&1 && docker --version          || echo '미설치')"
printf '  %-16s %s\n' "compose:" "$(docker compose version 2>/dev/null | head -n1                   || echo '미설치')"
printf '  %-16s %s\n' "uv:"      "$(command -v uv      >/dev/null 2>&1 && uv --version              || echo '미설치')"
printf '  %-16s %s\n' "vim:"     "$(command -v vim     >/dev/null 2>&1 && vim --version | head -n1  || echo '미설치')"

if [ "$IS_ROOT" -eq 0 ]; then
    echo
    c_warn "docker 를 sudo 없이 쓰려면 재로그인하거나 'newgrp docker' 를 실행하세요."
fi
