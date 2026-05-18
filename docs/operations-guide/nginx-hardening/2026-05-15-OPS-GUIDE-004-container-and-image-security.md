# [OPS-GUIDE-004] 컨테이너 / 이미지 보안

| 항목 | 값 |
| --- | --- |
| 문서 ID | OPS-GUIDE-004 |
| 시리즈명 | Nginx Production Hardening |
| 시리즈 인덱스 | [OPS-GUIDE-001 Master Index](./2026-05-15-OPS-GUIDE-001-master-index.md) |
| 생성일 | 2026-05-15 |
| 최근 검토일 | 2026-05-15 |
| 소유자 | 플랫폼 / SRE |
| 상태 | Living document |
| 다루는 영역 | 컨테이너 리소스 제한, read-only 루트 파일시스템, 이미지 취약점 스캐닝, SBOM / 이미지 서명, egress 필터링, 백엔드 격리 |

## 시리즈 내 위치

| 번호 | 문서 | 관계 |
| --- | --- | --- |
| OPS-GUIDE-001 | Master Index | 상위 인덱스 |
| OPS-GUIDE-002 | [TLS / 인증서 운영](./2026-05-15-OPS-GUIDE-002-tls-certificate-lifecycle.md) | 인접 — TLS 키 보관 / secrets 관리 |
| OPS-GUIDE-003 | [애플리케이션 계층 방어](./2026-05-15-OPS-GUIDE-003-application-layer-defense.md) | 인접 |
| **OPS-GUIDE-004** | **컨테이너 / 이미지 보안** *(이 문서)* | |
| OPS-GUIDE-005 | [운영 가시성](./2026-05-15-OPS-GUIDE-005-observability-and-operations.md) | 인접 — secrets 관리, 백업/DR 은 OPS-GUIDE-005 에 위치 |
| OPS-GUIDE-006 | [엣지 / 네트워크](./2026-05-15-OPS-GUIDE-006-edge-and-network.md) | 인접 — egress 필터링 (§5) 이 OPS-GUIDE-006 §4 DDoS playbook 과 연계 |

---

## 1. 컨테이너 리소스 제한

**Severity: High | Effort: XS**

### 1.1 근거

`mem_limit` 와 `cpus` 가 없는 docker 컨테이너는 호스트의 모든 자원을 소모할 수 있습니다. 호스트가 메모리 부족이 되면 커널 OOM killer 가 휴리스틱으로 victim 을 선택하는데, 종종 가장 큰 프로세스를 고르지만 multi-container 호스트에서는 무관한 서비스를 선택할 수도 있습니다. gunicorn 앱의 메모리 leak 가 가까이 있지도 않은 redis 컨테이너를 죽이는 식입니다.

현재 `docker-compose.yml` (각 서비스 compose 디렉터리) 의 리소스 제한이 감사되지 않았습니다. nginx 자체는 `worker_processes × worker_connections × ~50 KB` 와 공유 zone (addr+flood 100 MB + globalblacklist.conf maps ~50 MB) 으로 제한된 메모리를 사용 — 현재 설정 (8 × 4096) 에서 worst case 약 1.75 GB. nginx 컨테이너에 2 GB 제한은 안전.

### 1.2 현재 상태

검증되지 않음. compose 파일에 명시적 제한이 없으면 무제한.

### 1.3 구현

각 compose 파일 (`compose/web_service/nginx_<svc>/docker-compose.yml`) 에:

```yaml
services:
  webserver:
    image: nginx_<svc>-webserver
    deploy:
      resources:
        limits:
          memory: 2g
          cpus: '2.0'
        reservations:
          memory: 512m
          cpus: '0.5'
    # docker-compose v2 (swarm 미사용) shorthand:
    # mem_limit: 2g
    # cpus: 2.0
    # mem_reservation: 512m
    restart: unless-stopped
    # 부하 상황에서 nginx 에 영향을 미치는 커널 노브:
    sysctls:
      net.ipv4.tcp_tw_reuse: 1
      net.core.somaxconn: 4096
      net.ipv4.tcp_max_syn_backlog: 4096
```

백엔드 앱 컨테이너 (gunicorn / uwsgi / php-fpm) 의 제한은 측정된 working set + 안전 margin 으로 설정. `docker stats --no-stream` 으로 대표 워크로드 하에 1시간 프로파일링, peak 메모리 × 1.5.

### 1.4 검증

제한 적용 후 제어된 stress 테스트:

```bash
# 지속 트래픽 생성
docker run --rm --network host alpine/socat - TCP:localhost:80,fork \
  </dev/urandom > /dev/null 2>&1 &
# 메모리 압박 관찰
docker stats nginx-gunicorn-webserver --no-stream
```

`MEM USAGE / LIMIT` 컬럼 관찰. 컨테이너는 제한에 접근하되 초과하지 않아야 합니다. 제한에 도달하면 docker 가 컨테이너를 OOM kill (호스트 아님) — 이게 의도된 격리.

### 1.5 모니터링

- **`container_memory_working_set_bytes`** (cAdvisor / kube-state-metrics) — 제한의 >85% 가 15분 이상 지속될 때 alert.
- **`container_oom_events_total`** — 0 이 아닌 값은 즉시 page.
- **`container_cpu_cfs_throttled_seconds_total`** — 지속 throttle 은 `cpus` undersize 시사.

### 1.6 흔히 빠지는 함정

- **제한이 너무 낮아 throttle 발생.** `cpus: 0.5` 는 컨테이너에 초당 500ms CPU 를 의미하지만 nginx 의 epoll loop 은 bursty — 들어오는 연결 폭증이 평균 부하가 낮아도 throttle 한계에 도달할 수 있어 time-to-first-byte spike 로 나타남. `cpus` 는 관측된 peak 부하 × 2 로 설정.
- **Nginx OOM kill 이 cascade 유발.** nginx 사망 시 LB 가 unhealthy 로 감지하고 다른 곳으로 라우팅하지만, 짧은 gap 동안 클라이언트가 TCP RST 를 봄. <5s 재시작을 trigger 하는 sidecar health check 와 결합하고 `restart: unless-stopped` 보장.
- **공유 zone 이 제한에 포함됨.** addr / flood / globalblacklist zone 은 nginx 의 공유 메모리에 있으며 컨테이너 RSS 의 일부. zone 크기를 늘리면 (예: 50m → 200m) `mem_limit` 도 비례 증가.

### 1.7 롤백

- compose 파일에서 `deploy.resources` 또는 `mem_limit` / `cpus` 라인 제거 후 `docker compose up -d --force-recreate`. 이는 제한 자체를 해제 — OOM 사고 직전 대응으로만 사용하고 근본 원인 (메모리 leak / 부하 증가) 을 동시에 처리.

---

## 2. Read-only root filesystem

**Severity: Medium | Effort: M**

### 2.1 근거

공격자가 RCE 를 달성하면 (대부분 nginx 자체가 아닌 백엔드 앱의 취약 의존성으로) 첫 단계는 영속화 payload 를 떨어뜨리는 것입니다 — 웹루트 아래 `.php` webshell, cron entry 수정, SSH 키, backdoor 바이너리. 컨테이너 루트 파일시스템이 read-only 라면 writable 영역은 명시적 tmpfs 마운트와 named volume 뿐이라 공격자의 선택지가 극적으로 좁아집니다. Webshell 은 특히 무용 — nginx 가 찾을 수 없는 파일을 서빙할 수 없기 때문.

### 2.2 현재 상태

컨테이너는 default writable rootfs 로 실행. read-only 활성화되지 않음.

### 2.3 구현

각 compose 파일에:

```yaml
services:
  webserver:
    read_only: true
    tmpfs:
      - /tmp:size=64m,mode=1777
      - /var/run:size=8m
      - /var/cache/nginx:size=128m
    volumes:
      # 이미 있는 bind mount (logs, config, ssl) 는 그대로 유지.
      # 명시적 writable surface 이며 의도된 것.
```

nginx, certbot, ngxblocker 가 여전히 동작하는지 테스트:

```bash
docker compose up -d webserver
docker exec nginx-gunicorn-webserver nginx -t
docker exec nginx-gunicorn-webserver /usr/local/sbin/update-ngxblocker -c /etc/nginx
# update-ngxblocker 는 /etc/nginx/conf.d/globalblacklist.conf 에 쓰므로 그 경로가 writable 이어야 함
# read-only 면 실패
```

이는 첫 시도에 실패할 것 — `update-ngxblocker` 가 `/etc/nginx/conf.d/` 에 씁니다. 두 가지 옵션:

1. **`/etc/nginx/conf.d` 를 writable named volume 으로 마운트** — ngxblocker 가 자신의 파일을 업데이트할 수 있고 `/etc/nginx` 의 나머지는 read-only 유지.
2. **호스트에서 updater 실행** — sidecar 가 shared volume 에 쓰는 방식.

옵션 1 이 더 단순. compose 파일:

```yaml
volumes:
  nginx_conf_d:
    driver: local
services:
  webserver:
    read_only: true
    tmpfs:
      - /tmp:size=64m,mode=1777
      - /var/run:size=8m
      - /var/cache/nginx:size=128m
    volumes:
      - nginx_conf_d:/etc/nginx/conf.d
      - ./conf.d:/etc/nginx/conf.d:ro   # 운영자의 static config 를 overlay
```

이는 운영자 관리 conf.d 파일과 ngxblocker 관리 globalblacklist.conf 의 신중한 merge 가 필요 — 프로젝트가 이 overlay 문제를 피하기 위해 globalblacklist.conf 를 `/etc/nginx/globalblacklist.conf` (conf.d 밖) 에 두기로 한 역사적 결정. read-only 파일시스템에서도 같은 배치가 가장 깔끔.

### 2.4 검증 — Escape 시도

활성화 후 공격자처럼 시도:

```bash
docker exec nginx-gunicorn-webserver bash -c 'touch /tmp/foo && echo ok'  # OK — tmpfs
docker exec nginx-gunicorn-webserver bash -c 'touch /usr/share/nginx/html/x.php' # FAIL — read-only
docker exec nginx-gunicorn-webserver bash -c 'touch /etc/cron.d/evil'             # FAIL — read-only
docker exec nginx-gunicorn-webserver bash -c 'touch /etc/nginx/conf.d/evil.conf' # OK — conf.d 가 named-volume writable; tradeoff 수용
```

### 2.5 모니터링

"파일시스템이 read-only" 에 대한 직접 메트릭은 없음 — `docker inspect` 출력으로 확인:

```bash
docker inspect nginx-gunicorn-webserver \
  --format '{{ .HostConfig.ReadonlyRootfs }}'
```

이를 일일 compliance check 에 포함하여 운영 컨테이너가 의도된 보안 자세와 일치하는지 검증.

### 2.6 흔히 빠지는 함정

- **logrotate 가 조용히 실패.** logrotate 는 state 를 `/var/lib/logrotate/status` 에 씁니다. read-only rootfs 에서는 status 업데이트가 실패하고 logrotate 가 예측 불가하게 동작. `/var/lib/logrotate` 를 tmpfs 목록에 추가 (rotation 타임스탬프는 일 단위이므로 lifetime 수용 가능).
- **certbot 이 `/etc/letsencrypt` 에 caching** (현재 호스트 bind-mount 라 OK) — 단 work 디렉터리 `/var/lib/letsencrypt` 와 log 디렉터리 `/var/log/letsencrypt` 도 tmpfs 또는 volume 필요.
- **애플리케이션이 writable `/tmp` 필요** — tmpfs 크기가 worst-case 사용량 수용. 기본 64 MB 는 nginx 에 넉넉하지만 일부 앱 워크로드에는 빠듯.

### 2.7 롤백

- compose 파일에서 `read_only: true` 제거, `tmpfs` 블록 제거 후 `docker compose up -d --force-recreate`. 60초 이내 복귀.

---

## 3. 이미지 취약점 스캐닝

**Severity: Medium | Effort: S (일회성) + 지속 운영 비용**

### 3.1 근거

base image `nginx:1.27-bookworm` 은 Debian 패키지가 노후되면서 CVE 가 누적됩니다. 애플리케이션 코드가 완벽해도 TLS downgrade 를 허용하는 libssl CVE 는 이 이미지를 실행하는 모든 nginx 프로세스에 영향. 벤더 보안 업데이트 cycle (Debian LTS) 은 주간으로 패치를 push 하지만 이미지가 재빌드될 때만 land.

### 3.2 현재 상태

자동 스캐닝 미구성. 수동 트리거만 가능.

### 3.3 구현

세 가지 무료 오픈소스 스캐너가 검증됨:

- **Trivy** (aquasec) — 기본 추천, 가장 빠름, secret 스캐닝과 IaC 스캐닝 포함.
- **Grype** (anchore) — 순수 CVE 스캐너, DB 신선도 우수.
- **Docker Scout** (docker 무료 tier) — docker CLI 내장, 빠른 체크에 적합.

`Dockerfile` 을 건드리는 모든 PR 에 실행되는 CI job 추가 (예: GitHub Actions / GitLab CI):

```yaml
- name: nginx 이미지 CVE 스캔
  run: |
    docker build -t nginx_gunicorn-webserver:pr-${{ github.sha }} \
      -f devspoon-web/docker/nginx/Dockerfile devspoon-web/docker/nginx/
    trivy image --severity CRITICAL,HIGH \
      --exit-code 1 --ignore-unfixed \
      nginx_gunicorn-webserver:pr-${{ github.sha }}
```

CI 파이프라인이 없는 환경에서는 build 호스트에 Trivy 설치 후 주간 cron:

```bash
0 6 * * 1 trivy image --severity CRITICAL,HIGH --quiet \
  nginx_gunicorn-webserver:latest 2>&1 | mail -s "주간 CVE 스캔" ops@example.com
```

### 3.4 Triage 워크플로우

CRITICAL/HIGH CVE 가 보고되면 즉시 재빌드하지 마세요 — 대부분의 CVE 는 CVSS 가 높지만 매우 특정한 exploit 조건을 요구하며 본 환경에 해당하지 않을 수 있음.

1. 영향받는 패키지 식별.
2. 패키지가 실행 중 nginx 에 로드되는지 확인 (예: `cups` 의 CVE 는 무관 — 이미지에 있지만 nginx 가 호출하지 않음).
3. exploit 가능성 확인 — 취약 함수가 컨테이너가 실행하는 어떤 코드 경로에서 런타임에 호출되는가?
4. exploit 가능하면 Debian 이 bookworm 으로 fix 를 backport 했는지 확인. Trivy 의 `Fixed Version` 컬럼이 표시.
5. fix 존재 시 이미지 재빌드 후 배포. fix 없으면 보상 컨트롤 문서화 (예: 상위 WAF 룰) 후 주간 재방문.

### 3.5 모니터링

- **CRITICAL CVE 건수 추세** — 주간 스캔 결과를 시계열로 저장, 7일 이상 같은 CVE 가 미해결이면 alert.
- **Triage backlog 크기** — 월간 backlog ≤10 유지 (acceptance criteria).
- **Base image age** — `docker image inspect` 의 Created timestamp, 90일 이상 지나면 자동 재빌드 cron.

### 3.6 흔히 빠지는 함정

- **Unfixed CVE 의 noise overload.** `--ignore-unfixed` 없이 Trivy 는 fix 되지 않을 모든 알려진 CVE 를 반환. 일상 스캔에 항상 `--ignore-unfixed` 사용.
- **잘못된 이미지 스캐닝.** CI 는 빌드된 이미지를 스캔하지만 운영은 다른 tag 를 실행할 수 있음. 이미지에 git commit SHA 태그를 부여하고 배포가 정확히 그 tag 를 사용하는지 보장.
- **Base image drift.** `FROM nginx:1.27-bookworm` 은 시간이 흐름에 따라 다른 SHA 로 resolve. 운영에서 digest 로 pin: `FROM nginx:1.27-bookworm@sha256:abc123...`.

### 3.7 롤백

스캐닝 자체는 read-only 작업으로 롤백 개념이 없음. CVE 대응으로 한 이미지 재빌드가 회귀를 일으킨 경우, 이전 이미지 tag 로 `docker compose up -d --force-recreate`.

---

## 4. SBOM 및 이미지 서명 (§4.15.4)

**Severity: Medium | Effort: M**

### 4.1 근거

레지스트리 자체가 침해될 수 있습니다. 공격자가 운영 레지스트리에 push 권한을 얻으면 동일한 tag 의 악성 이미지로 정상 이미지를 교체할 수 있고, deploy 시점에는 감지되지 않습니다. **이미지 서명** 은 deploy 시점에 "이 이미지는 우리가 빌드했다" 를 검증. **SBOM (Software Bill of Materials)** 은 이미지에 포함된 모든 컴포넌트 목록을 변경 불가능한 attestation 으로 제공.

### 4.2 구현

#### 4.2.1 SBOM 생성 (`syft`)

CI 빌드 단계 직후:

```bash
syft nginx_gunicorn-webserver:${TAG} -o spdx-json > sbom-${TAG}.spdx.json
syft nginx_gunicorn-webserver:${TAG} -o cyclonedx-json > sbom-${TAG}.cdx.json
```

두 포맷 (SPDX, CycloneDX) 모두 생성하는 이유는 다른 도구가 다른 포맷을 요구하기 때문. 양 SBOM 파일을 registry 의 referrers API 로 attach 하거나 별도 artifact storage 에 보관.

#### 4.2.2 이미지 서명 (`cosign`)

```bash
# 빌드 후
cosign sign --key cosign.key nginx_gunicorn-webserver:${TAG}
```

key 관리는 별도 secrets store (Vault, AWS KMS, GCP KMS). cosign 의 keyless 모드 (OIDC + Sigstore) 가 더 안전 — short-lived 인증서를 사용해 키 노출 위험 제거.

#### 4.2.3 deploy 시점 검증

deploy 스크립트 또는 admission controller 에서:

```bash
cosign verify --key cosign.pub nginx_gunicorn-webserver:${TAG} || exit 1
docker compose up -d --force-recreate webserver
```

k8s 환경이라면 **Sigstore policy-controller** 또는 **kyverno** 가 admission 단계에서 검증.

### 4.3 검증

- SBOM 누락 이미지로 deploy 시도 → 거부됨을 확인.
- 외부 키로 서명된 이미지로 deploy 시도 → 거부됨을 확인.
- 정상 키로 서명된 이미지로 deploy → 통과 확인.

### 4.4 모니터링

- 서명 검증 실패 횟수를 메트릭으로 노출. 0 이 아닌 값은 즉시 page (공급망 공격 가능성).
- SBOM 생성 실패는 CI 단계에서 hard fail.

### 4.5 흔히 빠지는 함정

- **Key rotation 누락.** Cosign key 는 정기 rotation 필수. keyless 모드 사용 시 무관.
- **deploy 검증 우회.** "긴급 hotfix" 를 위한 검증 우회 경로가 항상 만들어지지만 공격자가 이를 악용. 우회 경로는 별도 감사 로그 + 사전 승인 필수.
- **SBOM 부정확.** `syft` 는 패키지 매니저 메타데이터에 의존 — 수동 빌드된 바이너리는 SBOM 에서 누락됨. 멀티 스테이지 빌드 시 모든 stage 에 대한 SBOM 결합 필요.

### 4.6 롤백

- 서명/검증 비활성: deploy 스크립트의 `cosign verify` 호출 제거. 단 이는 공급망 공격에 노출되므로 임시 조치.

---

## 5. Egress 필터링 (§4.15.5)

**Severity: Medium | Effort: M**

### 5.1 근거

nginx 컨테이너의 정당한 outbound 연결은 매우 제한적입니다: 백엔드 upstream (내부 네트워크), Let's Encrypt (port 80/443 to acme-v02.api.letsencrypt.org), ngxblocker 소스 (raw.githubusercontent.com), OCSP responder (인증서별로 다른 URL). 그 외 모든 outbound 는 의심스러움 — 컨테이너 침해 시 attacker 의 C2 서버로 나가는 콜백을 차단하는 효과.

### 5.2 구현

#### 5.2.1 Docker network policy (단일 호스트)

docker compose 의 user-defined bridge 와 iptables OUTPUT 룰 조합:

```yaml
# docker-compose.yml
networks:
  egress_restricted:
    driver: bridge
    internal: false  # outbound 일부 허용
services:
  webserver:
    networks:
      - egress_restricted
```

호스트 측 iptables (또는 DOCKER-USER chain) 에:

```bash
# nginx 컨테이너의 source 네트워크에서 허용된 destination 만 허용
iptables -I DOCKER-USER 1 -s 172.20.0.0/24 -d acme-v02.api.letsencrypt.org -j ACCEPT
iptables -I DOCKER-USER 2 -s 172.20.0.0/24 -d raw.githubusercontent.com -j ACCEPT
iptables -I DOCKER-USER 3 -s 172.20.0.0/24 -d <backend internal IP> -j ACCEPT
iptables -I DOCKER-USER 4 -s 172.20.0.0/24 -j REJECT  # default deny
```

destination 이 도메인이므로 실제로는 DNS 조회 결과 IP 또는 ipset 으로 관리. DNS 가 자주 바뀌는 경우 동적 ipset 갱신 스크립트 필요.

#### 5.2.2 k8s NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nginx-egress
spec:
  podSelector:
    matchLabels:
      app: nginx
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except: [10.0.0.0/8, 192.168.0.0/16]
      ports:
        - port: 80
        - port: 443
```

### 5.3 검증

```bash
# 정당한 outbound
docker exec nginx-gunicorn-webserver curl -sI https://raw.githubusercontent.com
# 예상: HTTP/2 200

# 비정당 outbound (시뮬레이션)
docker exec nginx-gunicorn-webserver curl -sI --max-time 5 https://attacker.example.com
# 예상: timeout 또는 connection refused
```

### 5.4 모니터링

- iptables `DROP` 카운터 — 시간 단위로 0 이 아니면 컨테이너 침해 또는 오설정 시사.
- `update-ngxblocker` cron 의 성공률 — egress 룰 실수로 차단했으면 갱신 실패.
- certbot 갱신 시도 빈도 — Let's Encrypt 도달 불가하면 갱신 실패 로그 발생.

### 5.5 흔히 빠지는 함정

- **DNS 변경.** GitHub / Let's Encrypt 가 IP 를 변경하면 ipset 이 stale. 일일 동적 갱신 스크립트 또는 더 넓은 CIDR 허용.
- **OCSP responder URL.** 인증서마다 다르며 변경됨. `openssl x509 -in fullchain.pem -text | grep OCSP` 로 확인 후 허용.
- **Container DNS resolver 도달 불가.** egress 룰이 53 포트 outbound 를 차단하면 컨테이너 DNS 가 깨짐.

### 5.6 롤백

- iptables 룰 제거: `iptables -F DOCKER-USER`.
- k8s NetworkPolicy 삭제: `kubectl delete netpol nginx-egress`.

---

## 6. 백엔드 컨테이너 격리 (§4.15.6)

**Severity: Medium | Effort: S**

### 6.1 근거

백엔드 gunicorn/uwsgi/php 컨테이너는 nginx 에서만 연결을 받아야 합니다. 임의의 다른 컨테이너에서 접근 가능하면 한 컨테이너 침해가 측면 이동으로 이어집니다.

### 6.2 구현

docker compose 의 network 분리:

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # outbound 자체 차단

services:
  webserver:
    networks: [frontend, backend]
  app:
    networks: [backend]  # frontend 에 직접 노출 안됨
  redis:
    networks: [backend]
```

이 구성에서 app 과 redis 는 backend network 에서만 보이고, 외부에서 직접 접근 불가. nginx 만 양 네트워크에 속해 트래픽을 proxy.

### 6.3 검증

```bash
# 백엔드 컨테이너가 외부에 직접 노출되지 않음을 확인
docker exec nginx-gunicorn-webserver curl -sI http://app:8000  # OK
docker exec another-unrelated-container curl -sI http://app:8000  # 실패 (network 분리)
```

### 6.4 모니터링

- network 정책 위반 시도 (정의되지 않은 inter-container 연결 시도) 를 docker daemon log 또는 cilium/calico 로그에서 추출.

### 6.5 흔히 빠지는 함정

- **명시 안 된 service 가 default network 에 떨어짐.** compose 의 모든 service 에 `networks:` 명시 필수.
- **공유 secret 으로 인한 측면 이동.** network 분리만으로 측면 이동을 완전히 막을 수 없음 — secret/credential 도 함께 분리.

### 6.6 롤백

- compose 의 network 정의에서 `internal: true` 제거 후 `docker compose up -d --force-recreate`.

---

## 7. References

- **CIS Docker Benchmark** — https://www.cisecurity.org/benchmark/docker
- **Trivy** — https://aquasecurity.github.io/trivy/
- **Syft (SBOM 생성)** — https://github.com/anchore/syft
- **Cosign / Sigstore** — https://docs.sigstore.dev/
- **Docker security best practices** — https://docs.docker.com/engine/security/
- **Kubernetes NetworkPolicy** — https://kubernetes.io/docs/concepts/services-networking/network-policies/

---

## 8. Change Log

| 날짜 | 작성자 | 변경 |
| --- | --- | --- |
| 2026-05-15 | 초기 작성 | OPS-GUIDE-001 마스터에서 분기. 리소스 제한, read-only fs, 이미지 스캐닝, SBOM/서명, egress 필터링, 백엔드 격리 포함. |
