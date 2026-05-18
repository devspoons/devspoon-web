"""
Gunicorn Configuration (Django sync)
=====================================================
환경: Production Level
서버 사양: 8 core CPU / 8 GB RAM
배포 정책: 수동 stop/start (무중단 미고려) → preload_app=True 로 메모리 절감 채택
백엔드: Django (WSGI sync)
프록시: Nginx (SSL/TLS, DDoS, Rate Limiting 처리)
=====================================================
"""

# ============================================================================
# 네트워크 바인딩
# ============================================================================
# Docker 컨테이너 환경: 0.0.0.0:8000 으로 nginx upstream 수신
bind = "0.0.0.0:8000"

# ============================================================================
# Worker 프로세스
# ============================================================================
# 산정:
#   - I/O 권장 공식: (cores * 2) + 1 = 17 — 다만 8GB RAM 제약으로 메모리 우선 산정
#   - sync 워커 (Django) 메모리: preload_app=True 기준 약 200-300MB / worker
#   - 9 워커 × 250MB ≈ 2.25GB (시스템/캐시/celery 등 공존 가능)
#   - threads=4 로 워커당 4 요청 동시 처리 (DB I/O 대기 흡수)
#   - 결과: 동시 처리 슬롯 = 9 * 4 = 36
workers = 9
threads = 4
worker_class = "sync"

# sync worker 용 (gthread 변경 시 동작) — Nginx 가 앞단에서 흡수하므로 보수적 값
worker_connections = 1000

# ============================================================================
# 프로세스 관리
# ============================================================================
# Docker 가 프로세스 라이프사이클 관리
daemon = False

# Django wsgi 엔트리포인트
wsgi_app = "config.wsgi:application"

# ============================================================================
# 타임아웃
# ============================================================================
# 일반 Django API 응답 + 파일 업로드 여유 고려
# Nginx proxy_read_timeout 보다 짧거나 같게
timeout = 60

# Nginx keepalive_timeout 보다 짧게 설정 (Nginx 가 먼저 종료)
keepalive = 5

# SIGTERM 후 graceful 처리 시간 (수동 stop 배포 시 적용)
graceful_timeout = 30

# ============================================================================
# 메모리 누수 방어
# ============================================================================
# 8GB 환경에서 8c 처리량을 고려해 헤드룸 확보 (1000 → 2000)
# - 50 req/s 환경에선 워커당 ~40초마다 재시작
# - 100+ req/s 환경에선 메모리 누수 모니터링 후 5000+ 로 확장
max_requests = 2000
max_requests_jitter = 200  # 모든 워커 동시 재시작 방지 (max_requests 의 10%)

# ============================================================================
# 애플리케이션 로딩
# ============================================================================
# 수동 stop/start 배포 → preload_app=True 유지
# - 메모리 20-40% 절감 (Copy-on-Write)
# - graceful reload (kill -HUP) 는 사용하지 않음
preload_app = True

# 코드 변경 자동 감지: 프로덕션 금지
reload = False

# ============================================================================
# 로깅 (모든 로그는 /log/gunicorn/ 식별 폴더에 일원화)
# ============================================================================
loglevel = "info"
capture_output = False
enable_stdio_inheritance = True

accesslog = "/log/gunicorn/gunicorn_access.log"
errorlog = "/log/gunicorn/gunicorn_error.log"

access_log_format = (
    '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s %(p)s'
)

# 프로세스 이름 (ps/htop 식별 용이)
proc_name = "django_gunicorn"

# ============================================================================
# Accept Queue / TCP backlog
# ============================================================================
# 8c 환경에서 burst 트래픽 흡수용으로 기본 2048 → 그대로 유지
# 시스템 net.core.somaxconn 과 함께 조정 (sysctl net.core.somaxconn=4096 권장)
backlog = 2048

# 워커 임시 디렉토리: 기본(/tmp) 사용. 대용량 업로드가 잦다면 /dev/shm 검토
worker_tmp_dir = None

"""
운영 체크리스트:
1. logrotate (script/logrotate/gunicorn/) 가 /etc/logrotate.d/gunicorn 에 마운트되어
   /log/gunicorn/*.log 를 daily 로테이션
2. 헬스체크 엔드포인트 (/health) 구현 — Nginx upstream check 또는 docker healthcheck 연동
3. 부하 테스트 (wrk, locust) 로 workers/threads 조정 검증
4. 메모리 모니터링: htop -p $(pgrep -d',' gunicorn)
"""
