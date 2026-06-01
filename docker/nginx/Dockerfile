FROM nginx:1.27-bookworm

ENV TZ=Asia/Seoul \
    DEBIAN_FRONTEND=noninteractive

# ============================================================================
# 1. 시스템 도구 / 타임존 / cron / certbot / CA 단일 레이어
#    - apt-get update + install + cache cleanup 한 RUN 으로 묶어
#      이미지 크기 및 layer 수를 절감
# ============================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-utils \
        tzdata \
        ca-certificates \
        sendmail wget gnupg \
        cron logrotate certbot python3-certbot-nginx && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    update-ca-certificates && \
    chmod 644 /etc/ssl/certs/ca-certificates.crt && \
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================================
# 2. Certbot 자동 갱신 Cron 등록
#    - deploy-hook: 컨테이너에 적합한 graceful reload (master 프로세스에 SIGHUP)
#    - nginx -t 로 사전 설정 검증 후 reload (잘못된 conf 가 즉시 prod 반영되는 사고 차단)
# ============================================================================
RUN crontab -l 2>/dev/null | { cat; echo "0 5 * * 1 certbot renew --quiet --deploy-hook \"nginx -t && nginx -s reload\" >> /log/nginx/crontab_$(date +\%Y\%m\%d).log 2>&1"; } | crontab -

# ============================================================================
# 3. nginx-ultimate-bad-bot-blocker 설치 (build 시점에 초기 데이터 bake-in)
#    - 다운로드: install-ngxblocker / setup-ngxblocker / update-ngxblocker 스크립트
#    - install-ngxblocker -x: /etc/nginx/conf.d/globalblacklist.conf 와 /etc/nginx/bots.d/* 생성
#      → 기존 정적 bad_bot.conf 를 globalblacklist.conf 가 대체 ($bad_bot 변수 동일)
#    - setup-ngxblocker 는 의도적으로 실행하지 않음 — server 블록 자동 수정은 sample_nginx*.conf
#      의 명시적 include 로 운영자가 제어
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    NGXB_URL=https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master && \
    curl -fsSL -o /usr/local/sbin/install-ngxblocker "$NGXB_URL/install-ngxblocker" && \
    curl -fsSL -o /usr/local/sbin/setup-ngxblocker   "$NGXB_URL/setup-ngxblocker"   && \
    curl -fsSL -o /usr/local/sbin/update-ngxblocker  "$NGXB_URL/update-ngxblocker"  && \
    chmod +x /usr/local/sbin/install-ngxblocker \
             /usr/local/sbin/setup-ngxblocker \
             /usr/local/sbin/update-ngxblocker && \
    # -c /etc/nginx 로 globalblacklist.conf 를 conf.d/ 밖에 둠.
    # 이유: compose 가 conf.d/ 디렉터리 전체를 호스트에서 mount → image 의 globalblacklist.conf 가 가려짐.
    #       /etc/nginx/ 는 mount 되지 않으므로 image 의 globalblacklist.conf 가 그대로 보임.
    /usr/local/sbin/install-ngxblocker -x -c /etc/nginx && \
    # install-ngxblocker 가 만들지 않는 사용자 커스텀 파일은 빈 파일로 생성 (sample_nginx*.conf include 깨짐 방지)
    touch /etc/nginx/bots.d/blacklist-domains.conf && \
    # botblocker-nginx-settings.conf 는 우리 nginx.conf 의 limit_*_zone addr 와 충돌 → 의도적으로 include 안 함.
    # (해당 파일은 image 에 존재하나 nginx.conf 가 include 하지 않으므로 무영향)
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# 4. ngxblocker 자동 갱신 Cron 등록 (6시간 간격)
#    - update-ngxblocker 가 /etc/nginx/conf.d/globalblacklist.conf 를 최신화
#    - 다운로드 성공 시에만 nginx -t && nginx -s reload (잘못된 conf 가 prod 즉시 반영 차단)
# ============================================================================
RUN crontab -l 2>/dev/null | { cat; echo "0 */6 * * * /usr/local/sbin/update-ngxblocker -c /etc/nginx >> /log/nginx/ngxblocker_$(date +\%Y\%m).log 2>&1 && nginx -t && nginx -s reload"; } | crontab -

# ============================================================================
# 5. Nginx 시작 스크립트에 Cron 추가
#    - docker-entrypoint.sh 의 'set' 라인 직전에 'cron' 실행 라인 삽입
#    - cron 데몬은 백그라운드 기동, nginx 가 PID 1 로 foreground 실행
# ============================================================================
RUN sed -i'' -r -e "/set/i\cron" docker-entrypoint.sh

# ============================================================================
# 6. HTTPS default_server 용 dummy 인증서 (방법 1: ssl_reject_handshake)
#    - SNI 미매칭 / IP 직접 HTTPS 접근에 대한 정보 누출 차단을 위해 conf.d/default.conf
#      의 443 default_server 블록을 활성화한다. 이 블록은 ssl_reject_handshake on; 으로
#      handshake 자체를 거부하지만, nginx 가 listen 443 ssl 블록을 파싱하려면 문법상
#      ssl_certificate / ssl_certificate_key 가 반드시 있어야 한다.
#    - 이 dummy 인증서는 응답에 노출되지 않으므로 도메인 이름이 의미 없다. CN=default-reject.
#    - openssl 은 nginx:1.27-bookworm 이미지에 기본 포함되어 있음.
#    - 자동 갱신 불필요 (10년 유효, 응답에 안 나가므로 만료/체인 검증 무관).
#    - 저장 경로: /etc/nginx/ssl/default/
#        · /etc/ssl/certs/ 는 compose 가 ssl/certs 를 통째로 bind-mount 하므로
#          빌드 시 생성한 파일이 가려진다. /etc/nginx/ 는 mount 대상이 아니므로 안전.
#          (globalblacklist.conf 가 /etc/nginx/ 에 위치한 것과 같은 이유)
# ============================================================================
RUN mkdir -p /etc/nginx/ssl/default && \
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -subj "/CN=default-reject" \
        -keyout /etc/nginx/ssl/default/privkey.pem \
        -out   /etc/nginx/ssl/default/fullchain.pem && \
    chmod 644 /etc/nginx/ssl/default/fullchain.pem && \
    chmod 600 /etc/nginx/ssl/default/privkey.pem

# ============================================================================
# 7. CA 인증서 번들 최종 재생성 (★ 마지막 단계)
#    - 이전 RUN 단계들이 apt-get autoremove/clean 으로 /etc/ssl/certs/ 를 비울 수 있음
#    - update-ngxblocker 가 raw.githubusercontent.com 으로 curl 할 때 ca-certificates.crt 필수
#    - 본 RUN 을 Dockerfile 최하단에 두어 다른 RUN 의 cleanup 영향을 받지 않게 함
# ============================================================================
RUN update-ca-certificates && \
    test -s /etc/ssl/certs/ca-certificates.crt && \
    chmod 644 /etc/ssl/certs/ca-certificates.crt

# ============================================================================
# 8. DH 파라미터(ssl_dhparam) 빌드 시 1회 생성하여 이미지에 굽는다
#    - 현재 cipher 정책은 ECDHE 전용(TLS1.2/1.3)이라 실제 핸드셰이크엔 쓰이지 않지만,
#      향후 DHE 추가 대비 + nginx ssl_dhparam 지시어 유지를 위해 단일 공유본을 둔다.
#      (dhparam 은 비밀이 아니고 도메인 종속도 아니므로 전 도메인 공유로 충분)
#    - 위치는 /etc/nginx/dhparam.pem — compose 는 /etc/nginx/{conf.d,nginx.conf,proxy_params}
#      만 개별 마운트하므로 이 파일은 가려지지 않는다. (과거엔 /etc/ssl/certs 아래에 두어
#      호스트 볼륨이 시스템 CA 번들 ca-certificates.crt 를 가려 certbot 이 실패했었음)
# ============================================================================
RUN openssl dhparam -out /etc/nginx/dhparam.pem 2048 && \
    chmod 644 /etc/nginx/dhparam.pem

# ============================================================================
# 9. dhparam 백업/복원 훅 (nginx 기동 전, 마운트 적용 후 실행)
#    - 호스트 볼륨(/etc/nginx/dhparam-backup, compose 에서 ./ssl/dhparam 마운트)에
#      백업본이 있으면 복원해 사용 → 이미지를 재빌드해 dhparam 이 새로 구워져도
#      운영 중이던 동일 키를 유지한다 (docker compose down 후 up 시에도 동일 키 유지).
#    - 백업본이 없으면(최초 기동) 이미지에 구운 dhparam 을 백업 디렉터리로 복사해 둔다.
#    - nginx 공식 이미지의 /docker-entrypoint.d/*.sh 훅 사용 → nginx 기동 직전 알파벳 순 실행.
# ============================================================================
RUN printf '#!/bin/sh\nset -e\nBK=/etc/nginx/dhparam-backup/dhparam.pem\nLV=/etc/nginx/dhparam.pem\nmkdir -p /etc/nginx/dhparam-backup\nif [ -s "$BK" ]; then\n  cp -f "$BK" "$LV"\nelse\n  cp -f "$LV" "$BK"\nfi\n' > /docker-entrypoint.d/20-dhparam.sh && \
    chmod +x /docker-entrypoint.d/20-dhparam.sh
