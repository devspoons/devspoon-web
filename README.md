# devspoon-web

This open source project offer docker that three kind of web or API service solutions by php, gunicorn, uwsgi based on nginx server.
You can easily create custom configuration files for nginx using a shell script.
Supports https and certbot auto-extension script.
there are default security settings in the nginx config file.
docker-compose allows you to easily install and operate multiple domain servers on one server.
For server caches, docker-compose supports installing and connecting redis and redis-state.
Anyone can install web services easily using docker and docker-compose.
Af you want to use python and php service at same time, this solution can help you better.

# introduce "Devspoon-Projects"

- We provide an open source infrastructure integration solution that can easily service Python, Django, PHP, etc. using docker-compose. You can install the commercial-level customizable nginx service and redis at once, and install and manage more services at once. If you are interested, please visit [Devspoon-Projects](https://github.com/devspoon/Devspoon-Projects).

# Official guide document

- preparing...

## Features

- **Support to make configuration files for each service(conf, certbot)** : You can use a shell script to generate conf files for https and proxy settings in nginx. Supports a script to restart docker using crontab to complete certbot authentication of the docker container.

- **Efficiently dockerfile configuration for development and service operation** : The log folder is interlocked by "volumes" in docker-compose.yml so that user can can be tracked problems even when the docker container is stopped. Webroot, nginx config, etc. are frequently modified during development so these are interlocked by "volumes"

- **Provide reverse proxy function** : Multiple web and app services can be provided through one nginx with php or python and services can be provided simultaneously. A shell script is provided to easily create a proxy config file so that it can be integrated with the web UI of other services.

- **Provides easy distributed service operation method** : You can use multiple web servers through proxy, and you can use multiple app servers on one web server.

- **Easy service changes using Docker-compose** : In docker-compose, various configuration items are defined and commented out. By deleting comments or adjusting your desired settings, you can easily create an environment that suits your purposes.

- **log file collection** : Log files for all services are stored in log/<service> and can be monitored even after container termination.

- **redis and ssl** : Information such as configuration files, data, and keys for Redis and SSL are attached as volumes to the redis and ssl folders in docker-compose, so they can be reused when the container is terminated and restarted.

## Considerations

- **No DB service** : This open source does not provide DB as docker to suggest stable operation. It is recommended to install it on a real server and access it using a network, such as port 3306. We hope that this will be done for distributed services as well. We hope that this will be consider for distributed services as well.

- **Development-oriented docker service** : This open source is designed for focused on development-oriented rather than perfect docker container distribution and is suitable for startups or new service development teams with frequent initial modifications and tests.

- **Considering on-premise servers** : This solution is built for on-premises servers. However, since it is currently being used as a test and commercial service in OCI (Oracle Cloud Infrastructure), it can be used in environments such as AWS and GCP without problems.

## Operations Guide

운영 가이드는 [`docs/operations-guide/nginx-hardening/`](docs/operations-guide/nginx-hardening/) 아래에 시리즈로 관리됩니다. 시작점은 [**OPS-GUIDE-001 Master Index**](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-001-master-index.md) — 위협 모델, 우선순위 매트릭스, 분기별 로드맵, 시리즈 인덱스를 포함합니다. 각 sub-guide 는 도메인 단위로 분리되어 독립적으로 갱신됩니다:

| 번호 | 문서 | 다루는 영역 |
| --- | --- | --- |
| OPS-GUIDE-001 | [Master Index](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-001-master-index.md) | 위협 모델, 우선순위 매트릭스, 로드맵, 공통 롤백, 시리즈 인덱스, review/update 정책 |
| OPS-GUIDE-002 | [TLS / 인증서 운영](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-002-tls-certificate-lifecycle.md) | 인증서 만료 모니터링, HSTS preload, Let's Encrypt 계정 백업 |
| OPS-GUIDE-003 | [애플리케이션 계층 방어](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-003-application-layer-defense.md) | WAF (ModSecurity + OWASP CRS), fail2ban, CSP 단계적 도입 |
| OPS-GUIDE-004 | [컨테이너 / 이미지 보안](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-004-container-and-image-security.md) | 리소스 제한, read-only filesystem, 이미지 취약점 스캐닝, SBOM/서명, egress 필터링, 백엔드 격리 |
| OPS-GUIDE-005 | [운영 가시성 / 로그 / 메트릭](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-005-observability-and-operations.md) | 로그 회전, Observability 스택, 커스텀 에러 페이지, 감사 로그 immutability, secrets 관리, 백업/DR |
| OPS-GUIDE-006 | [엣지 / 네트워크](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-006-edge-and-network.md) | HTTP/3, real_ip, SSL mount 범위, Slowloris, CONTINUATION flood, DDoS playbook |

각 문서는 근거(Why) → 현재 상태 → 구현 단계 + 설정 스니펫 → 검증 방법 → 모니터링 → 롤백 → 흔히 빠지는 함정 의 7개 절로 구성됩니다. PR 은 시리즈 ID 를 제목에 명시 (`OPS-GUIDE-003: WAF Phase 2 exclusion 추가`) 하여 분기 review 가 추적 가능하게 합니다.

## Install & Run

1. Make webroot folder

   ```
   User have to make new folder under www path

   Example : /www/home_test
   ```

2. Make a conf file of nginx

   - PHP service (PHP 7.3 / 8.4 dual-version)

     > The PHP stack ships in two parallel versions selectable per deployment:
     > - **PHP 7.3** (legacy) — `romeoz/docker-phpfpm:7.3` base, Debian multi-version paths (`/etc/php/7.3/fpm/...`)
     > - **PHP 8.4** (current) — official `php:8.4-fpm-bookworm` base, single-path layout (`/usr/local/etc/php{,-fpm.d}/...`)
     >
     > Each version has its own Dockerfile, compose stack, and PHP config folder (php.ini patched for PHP 8.x removals). The nginx config folder is shared because nothing in it depends on the PHP version. Both stacks bind ports 80/443, so they cannot run simultaneously — pick one per host.

     - **PHP service installation [nginx for php]** (shared between 7.3 and 8.4)

       ```
       In config/web-server/nginx/php
       There are 2 shell scripts (nginx_conf.sh, nginx_https_conf.sh)
       Use "chmod +x xxxx.sh" command, you activate shell script and run. then it make conf file
       nginx's a conf file will be in conf.d folder
       if your webroot path has sub-level, input type must be following as "\\/www\\/shop\\/shop_kings
       ```

       ```
       Shell script required informations like bellow
       webroot : ex -> shop_kings
       domain : ex -> xxxx.com
       portnumber : ex -> 80
       appname : ex -> php-app-7.3   (for the PHP 7.3 stack)
                  or  php-app-8.4   (for the PHP 8.4 stack)
                  → must match container_name in compose/web_service/nginx_php-<ver>/docker-compose.yml
       serviceport : ex -> 9000 (php-fpm listen port; same in both stacks)
       filename : ex -> xxxx (it's the name for nginx's conf file)
       ```

     - **PHP service installation [php application]** (version-specific folder)

       ```
       PHP 7.3 → config/app-server/php-7.3
       PHP 8.4 → config/app-server/php-8.4
                 (php.ini is patched for PHP 8.x removals: track_errors, sql.safe_mode,
                  session.hash_*, [Interbase], [mcrypt] sections removed; error_reporting
                  cleaned of ~E_STRICT; session.use_only_cookies / use_trans_sid /
                  referer_check commented out. Each patch is annotated inline with a
                  "; [PHP 8.4] ..." comment in the file.)

       Each folder contains 1 shell script (php_conf.sh) that generates the pool config.
       Use "chmod +x xxxx.sh" command to activate, then run. It writes to pool.d/.
       ```

     - **Run docker-compose.yml** (pick one version)

       ```
       PHP 7.3 →  cd compose/web_service/nginx_php-7.3
       PHP 8.4 →  cd compose/web_service/nginx_php-8.4

       Execute docker-compose.yml using "docker compose up -d" command.
       Before first start, copy .env.example to .env and fill in REDIS_PASSWORD
       (placeholder REDIS_PASSWORD=CHANGE_ME_REDIS_PASSWORD must be replaced).
       redis is gated by "profiles: redis" in PHP stacks — start it via:
           docker compose --profile redis up -d

       Cannot run both stacks at once: both bind host ports 80/443.
       To switch versions: "docker compose stop" in the running stack first, then "up -d" in the other.
       ```

   - Gunicorn service

     - **Gunicorn service installation [nginx for gunicorn]**

       ```
       In config/web-server/gunicorn
       There are 2 shell script
       Use "chmod +x xxxx.sh" command, you activate shell script and run.sh then it make conf file
       nginx's a conf file will be in conf.d folder
       * if your webroot path has sub-level, input type must be following as "\\/www\\/shop\\/shop_kings
       ```

       ```
       Shell script required informations like bellow
       webroot : ex -> shop_kings
       domain : ex -> xxxx.com
       portnumber : ex -> 80
       appname : ex -> gunicorn-app (user must be use "container name" referenced in docker-compose.yml file)
       serviceport : ex -> 8000 (gunicorn application service port)
       filename : ex -> xxxx (it's the name for nginx's conf file)
       ```

     - **Gunicorn service installation [gunicorn application]**

       ```
       * If user want to use config.py, user have to modify run.sh file in docker/gunicorn/
       In docker/gunicorn/

       Dockerfile required run.sh file to start gunicorn service in a container
       There are 2 shell script, make_run.sh and run.sh in /docker/gunicorn

       if you want to use sample project django_test in /www/py37, you can use run.sh.
       if you want to use new project, you must make run.sh using make_run.sh
       * when you input the path, considered "\\/www\\/shop\\/shop_kings
       ```

     - **Run docker-compose.yml**

       ```
       Get move to compose/web_service/nginx_gunicorn
       Before first start, copy .env.example to .env and fill in REDIS_PASSWORD,
       FLOWER_ID, FLOWER_PWD. CELERY_BROKER_URL is no longer stored in .env —
       it is composed from REDIS_PASSWORD at compose time (SSOT, see §0.5.3).

       Run docker-compose.yml using "docker compose up -d".
       For celery / celery-beat / flower: "docker compose --profile celery up -d".
       (redis-stats has been removed — see §0.5.7)
       ```

   - UWSGI service

     - **UWSGI service installation [nginx for uwsgi]**

       ```
       In config/web-server/uwsgi
       There are 2 shell script
       Use "chmod +x xxxx.sh" command, you activate shell script and run.sh then it make conf file
       nginx's a conf file will be in conf.d folder
       * if your webroot path has sub-level, input type must be following as "\\/www\\/shop\\/shop_kings
       ```

       ```
       Shell script required informations like bellow
       webroot : ex -> shop_kings
       domain : ex -> xxxx.com
       portnumber : ex -> 80
       appname : ex -> uwsgi-app (user must be use "container name" referenced in docker-compose.yml file)
       serviceport : ex -> 8000 (uwsgi application service port)
       filename : ex -> xxxx (it's the name for nginx's conf file)
       ```

     - **UWSGI service installation [uwsgi application]**

       ```
       In config/app-server/uwsgi
       There are a file of uwsgi_conf.sh
       you can make uwsgi.ini using this shell script file
       ```

       ```
       Dockerfile required run.sh file to start gunicorn service in a container
       There are 2 shell script, make_run.sh and run.sh in /docker/uwsgi

       if you want to use sample project django_test in /www/py37, you can use run.sh.
       if you want to use new project, you must make run.sh using make_run.sh
       * when you input the path, considered "\\/www\\/shop\\/shop_kings
       ```

     - **Run docker-compose.yml**
       ```
       Get move to compose/web_service/nginx_uwsgi
       Before first start, copy .env.example to .env and fill in REDIS_PASSWORD,
       FLOWER_ID, FLOWER_PWD. CELERY_BROKER_URL is no longer in .env (see §0.5.3).

       Execute docker-compose.yml using "docker compose up -d".
       For celery / celery-beat / flower: "docker compose --profile celery up -d".
       (redis-stats has been removed — see §0.5.7)
       ```

## How to develop based on working server

- User can access using defined folders in docker-compose.yml

  ```
  Example -> nginx container has volumes like below that

  /www
  /script/
  /etc/nginx/conf.d/
  /etc/nginx/nginx.conf
  /etc/nginx/uwsgi_params
  /ssl/
  /log
  ```

  - If user run containers at same server, can update code and move files directly from local server folder to container folder.

- If user use firewall, have to add required port number (refer each docker-compose.yml files)

  ```
  Example

  ufw allow 80/tcp
  ufw allow 3306/tcp
  ```

## Setting up HTTPS on a web server

- This step requires running http nginx server

  1. Run nginx_conf.sh located in config/web-server/nginx/<service>. Create a conf file for each domain under config/web-server/<service>/conf.d/.

  2. Please edit compose/web-service/<service>/docker-compose directly and run it according to the service you want to use.

  3. This will run the default nginx using http.

  4. The "docker exec -it bash" command allows users to access docker internals.

  5. The script/letsencrypt.sh shell script file is linked per volume. This allows users to access script files directly from the nginx container.

  6. Run script/letsencrypt.sh and enter information such as web root, domain, and email. This script automatically creates an SSL key for your volume if it does not exist.

  7. If you entered all keys correctly, use the exit command to exit the container.

  8. Now we need to create a conf file for https and delete the existing file.

  9. Run nginx_https_conf.sh located in config/web-server/nginx/<service>. Create a conf file for each domain under config/web-server/<service>/conf.d/.

  10. Users must remove the http conf file from config/web-server/<service>/conf.d/.

  11. Run the “docker-compose restart” command in the compose folder. You can also use the “docker-compose stop” and “docker-compose start” commands in the compose folder. Do not use the "docker-compose down" command. Related configuration files may be deleted.

  12. To reflect this, you must use certbot to restart the container whose keys are automatically updated. Runs a script matching script/crontab\_<service> outside the container.

  13. You can use crontab -l to check if it is registered properly.

## 운영자 가이드 (Operator's Manual)

> 본 섹션은 인프라/운영자 관점에서 본 프로젝트를 안전하게 배포·운영하기 위한 사전 지식, 권장 설정, 그리고 주의해야 할 동작을 정리한 문서입니다. **프로덕션 배포 전에 반드시 읽어주세요.**

### 0. 기준 환경 및 배포 정책

| 항목 | 값 | 비고 |
|---|---|---|
| 서버 사양 | **8 core / 8 GB RAM** | 본 README 의 모든 튜닝 수치는 이 기준에서 산정됨. 사양이 다르면 워커/풀 수치 재산정 필요 |
| 배포 방식 | **수동 stop/start (무중단 미고려)** | `docker compose stop` → 코드 갱신 → `docker compose start`. zero-downtime / blue-green / rolling 미지원 |
| 컨테이너 베이스 | `ubuntu:24.04` (LTS), `nginx:1.27-bookworm` | latest 태그 금지 — 재현 가능 빌드 보장 |
| Python | `3.14.0` (소스 컴파일, multi-stage builder + SHA256 검증) | 빌드 시간 길지만 런타임 5-10% 빠름. SHA256 ARG default = `2299dae5...e9f3e9` (§0.5.4) |
| PHP 7.3 (legacy) | `romeoz/docker-phpfpm:7.3` | `docker/php-fpm/Dockerfile-7.3`. 멀티버전 경로(`/etc/php/7.3/fpm/...`). 업스트림 비유지보수 — 신규 배포는 8.4 권장 |
| PHP 8.4 (current) | `php:8.4-fpm-bookworm` (공식) | `docker/php-fpm/Dockerfile-8.4`. 단일 경로(`/usr/local/etc/php{,-fpm.d}/...`). php.ini 는 8.x 호환으로 패치됨 (`config/app-server/php-8.4/php_ini/php.ini`) |
| Redis | `redis:7.4-alpine` + `protected-mode yes` + `requirepass` | Alpine 베이스로 이미지 100 MB 이하. 인증 강제 (§0.5.2) |
| Flower | `mher/flower:2.0.1` | `master` 태그는 재현성 없으므로 금지. `FLOWER_BASIC_AUTH` 필수 |
| 이미지 태그 (이 프로젝트가 빌드) | `devspoon-py-app:latest`, `devspoon-uwsgi-app:latest`, `devspoon-nginx:latest`, `devspoon-php-app:{7.3,8.4}` | compose `image:` 명시로 스택 / 서비스 간 재사용 (§0.5.4) |

#### 왜 "수동 stop/start" 가 기본 정책인가?
- 본 프로젝트는 단일 서버(8c/8g) 운용을 1차 타깃으로 하며, 로드밸런서/오케스트레이터(K8s)가 없는 환경에서 가장 단순·안전한 배포 모델.
- 무중단(graceful HUP reload) 을 포기한 대신 **메모리 절감** 을 우선:
  - gunicorn `preload_app=True` (Copy-on-Write로 워커 메모리 20-40% 감소)
  - uwsgi `lazy-apps=false` (마스터에서 1회 로드 후 fork)
- 무중단이 필요해지는 시점은 별도 PR/마이그레이션으로 처리하는 것을 권장.

---

### 0.5. 2026-05 보안/구조 하드닝 (Recent Hardening Sweep)

본 절은 가장 최근에 일괄 적용된 정책 변경을 모아 둔다 — 이전 README 의 기본값과 다른 부분이 있으니 운영자는 반드시 본 절을 확인 후 §1 이하 운영 가이드를 읽을 것.

#### 0.5.1 자격증명 외부화 — `.env` 와 `.env.example`

- 6개 스택(daphne / gunicorn / uvicorn / uwsgi / php-7.3 / php-8.4) 각각의 `compose/web_service/<stack>/.env` 는 **git 추적 대상에서 제외**. 동일 폴더의 `.env.example` 만 추적되며, 신규 환경은 `cp .env.example .env` 후 자격증명을 채워 시작.
- `.gitignore` 의 패턴: `**/.env` (ignore) + `!**/.env.example` (예외 추적). 기존에 추적되던 5개 `.env` 는 `git rm --cached` 로 untrack 됨 (작업트리 보존).
- compose 의 `${VAR:?error}` 검증: 자격증명 키(`REDIS_PASSWORD` / `FLOWER_ID` / `FLOWER_PWD`) 가 미설정/빈문자열이면 `docker compose up` 단계에서 즉시 fail-fast → "비밀번호 빈값 기동" 사고 차단.
- 로그 옵션 키(`LOG_DRIVER` / `LOG_OPT_MAXF` / `LOG_OPT_MAXS`) 는 `${VAR:-default}` 로 fallback 처리되어 `.env` 누락에도 무영향.

#### 0.5.2 Redis 인증 강화 (`protected-mode yes` + `requirepass`)

- 6개 `redis.conf` 모두 `protected-mode no → yes`. 동일 docker network 내부에서도 인증 없이는 어떤 키에도 접근 불가.
- `requirepass` 값은 `redis.conf` 가 환경변수 보간을 지원하지 않으므로 compose 의 `command: redis-server ... --requirepass ${REDIS_PASSWORD}` 로 외부 주입.
- redis 컨테이너에 healthcheck 추가:
  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "redis-cli --no-auth-warning -a \"$$REDIS_PASSWORD\" ping | grep -q PONG"]
    interval: 10s
    timeout: 3s
    retries: 5
    start_period: 10s
  ```
- 앱 / celery / celery-beat / flower 의 `depends_on: redis` 가 `condition: service_healthy` 로 강화 — redis 가 인증 응답을 줄 때까지 의존 서비스 기동을 보류해 race condition 차단.

#### 0.5.3 `CELERY_BROKER_URL` 의 SSOT 화 (drift 차단)

- 과거 `.env` 에 `CELERY_BROKER_URL=redis://:PASS@redis:6379/3` 형태로 별도 보관 → `REDIS_PASSWORD` 와 두 값을 동기화해야 하는 drift 위험 존재.
- 이번 변경으로 `.env` 의 `CELERY_BROKER_URL` 키 **제거**. compose 의 celery / celery-beat / flower `environment:` 에서 `redis://:${REDIS_PASSWORD:?...}@redis:6379/3` 로 직접 합성 → **REDIS_PASSWORD 한 값만 갱신하면 4개 서비스가 동시에 동기화**.
- 추가 효과: 과거에는 celery / celery-beat 컨테이너에 `CELERY_BROKER_URL` 환경변수가 주입되지 않아 Django settings 가 `os.environ['CELERY_BROKER_URL']` 을 읽으면 기본값 `amqp://localhost` 로 떨어지는 잠재 버그 존재 → 본 변경으로 해소.

#### 0.5.4 Docker image 빌드 정책 변경

- `docker/gunicorn/Dockerfile` 와 `docker/uwsgi/Dockerfile` 을 **multi-stage** 로 재구성:
  - **builder** stage: `ubuntu:24.04` + `build-essential` + `*-dev` libs + Python 3.14 소스 컴파일 + pip 사전 설치 (native build 필요한 mysqlclient/psycopg2 등 포함).
  - **runtime** stage: `ubuntu:24.04` + 런타임 라이브러리만 + percona-xtrabackup-84 + pgbackrest + cron + logrotate. `build-essential` / `pkg-config` 제거되어 이미지 약 500MB 절감.
- Python tarball **SHA256 검증** 추가:
  - `ARG PYTHON_SHA256=2299dae542d395ce3883aca00d3c910307cd68e0b2f7336098c8e7b7eee9f3e9` (Python 3.14.0 공식, 2026-05-18 확인).
  - 빌드 단계에서 `sha256sum -c` 가 비0 종료하면 RUN 중단 → 공급망 변조 감지.
  - 버전 bump 시 [python.org Files 표](https://www.python.org/downloads/release/python-3140/) 또는 `.sigstore` bundle 검증 후 ARG 값 갱신.
- compose 의 `image:` 명시 태그로 stack 간 / 서비스 간 **재사용**:
  - `devspoon-py-app:latest` — gunicorn / daphne / uvicorn 3개 스택 + 각 스택 내 celery / celery-beat 가 공유.
  - `devspoon-uwsgi-app:latest` — uwsgi 스택 전용.
  - `devspoon-nginx:latest`, `devspoon-php-app:7.3` / `devspoon-php-app:8.4`.
  - 효과: `docker compose build` 가 동일 컨텍스트를 3-4회 재빌드하던 동작이 1회로 축소.

#### 0.5.5 uwsgi.ini 권한 강화

- `username = root` 제거 → `uid = www-data` / `gid = www-data` 활성. master 가 root 가 아닌 www-data 로 떨어지며 PHP-FPM 패턴과 대칭 (least-privilege).
- `chmod-socket = 666` 주석화 — TCP 8000 사용 시 무의미. 향후 unix socket 전환 시 0660 사용 안내가 인라인 코멘트로 추가됨.
- `sample_uwsgi.ini` 의 `py-autoreload = 1 → 0` — cookiecut 시 운영 부적합 기본값이 다시 도지지 않게 통일.

#### 0.5.6 ulimits — 변수 정의 후 명시적 비활성

- `.env` 에 `ULIMIT_NOFILE_SOFT=65535` / `ULIMIT_NOFILE_HARD=65535` 변수 정의.
- 6개 compose 의 `webserver` 서비스에 ulimits 블록은 **주석 처리 상태로** 포함 — 호스트 docker daemon 의 기본 LimitNOFILE (통상 1048576) 이 65535 를 충분히 수용하기 때문. 호스트 OS 차이로 nofile 한도가 65535 미만으로 잘리는 환경(RHEL / podman / 일부 K8s 노드)에서만 주석 해제하여 명시 활성화.

#### 0.5.7 redis-stats 제거

- `insready/redis-stat:latest` (2017년 이후 미관리, 보안 패치 없음) 가 모든 6개 compose 에서 삭제됨. 호스트 `63790/tcp` 노출도 함께 제거.
- 대체가 필요하면 RedisInsight 또는 `oliver006/redis_exporter` (Prometheus용) 도입 권장.

#### 0.5.8 PHP-FPM Dockerfile tzdata 패턴 통일

- `Dockerfile-7.3` / `Dockerfile-8.4` 에서 `dpkg-reconfigure tzdata` 제거. gunicorn / uwsgi / nginx Dockerfile 과 동일하게 `ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone` 패턴으로 통일.
- `Dockerfile-7.3` 의 중복 install layer 6개를 단일 RUN 으로 압축.

---

### 1. App-server 워커/풀 산정 근거

8 core / 8 GB 기준 메모리 가용량 계산: `8 GB - (OS + nginx + redis + 헤드룸 ≈ 2 GB) = 약 6 GB`.

| 서비스 | 핵심 수치 | 산정 근거 |
|---|---|---|
| **gunicorn (Django sync)** | `workers=9, threads=4` | (cores + 1) 보수치. 워커당 ~250 MB × 9 ≈ 2.25 GB. threads=4 로 DB I/O 대기 흡수 → 동시 슬롯 36 |
| **uvicorn (FastAPI ASGI)** | `workers=8` (UvicornWorker) | 비동기 워커는 단일 이벤트 루프로 다수 동시 처리. 1 worker / core. 워커당 ~600 MB × 8 ≈ 4.8 GB |
| **uwsgi (Django)** | `processes=8, threads=4` | sync 워커. `harakiri=60`, `reload-on-rss=800MB` (메모리 누수 자동 복구) |
| **daphne (ASGI WS)** | 단일 프로세스 | daphne 는 멀티프로세스 미지원. 동시 websocket 수천은 단일 인스턴스로 가능. 더 필요 시 nginx upstream + 다중 컨테이너 |
| **celery worker** | `--concurrency=8 --max-tasks-per-child=2000` | prefork 풀, 코어 매칭. 메모리 누수 방어 위해 2000 태스크마다 워커 재기동 |
| **php-fpm** (7.3/8.4 공용) | `pm.max_children=40, start=8, min_spare=8, max_spare=24` | 워커당 ~80 MB × 40 ≈ 3.2 GB. `request_terminate_timeout=60s` 로 hang 방지. 두 버전 모두 동일 pool 정책을 적용 — 각 버전 폴더(`config/app-server/php-7.3` / `php-8.4`)의 `pool.d/sample_php.conf` 내용은 동일하며, 차이는 php.ini 의 8.x 호환 패치뿐 |

> **주의 — `preload_app=True` 의 부수 효과**:
> - DB 커넥션을 모듈 import 시점에 열면 fork 후 워커들이 동일 소켓을 공유 → 충돌 가능.
> - 해결: DB 커넥션은 첫 요청 시 lazy 생성하거나, `post_fork` 훅에서 명시적으로 재생성.
> - Django ORM 은 자동 처리되지만, SQLAlchemy + raw psycopg2 등은 직접 챙길 것.

---

### 2. 로그 구조 (식별 가능한 일원화 구조)

**모든 로그는 호스트 측 `./log/` 하나로 일원화** 되며, 컨테이너 안에서는 `/log/` 로 마운트됩니다.

```
log/
├── nginx/              # nginx access/error + certbot 갱신 로그
├── gunicorn/           # gunicorn_access.log, gunicorn_error.log
│   ├── celery/         # worker-*.log
│   └── celerybeat/     # celerybeat.log
├── uvicorn/            # uvicorn_access.log, uvicorn_error.log
│   ├── celery/
│   └── celerybeat/
├── uwsgi/              # <project>-uwsgi.log, daemonize, _access.log
│   ├── celery/
│   └── celerybeat/
├── daphne/             # stdout.log, error.log, access.log
│   ├── celery/
│   └── celerybeat/
├── php-fpm/            # access.log, www-error.log, slow.log
└── supervisor/         # (예약 슬롯)
```

- **컨테이너가 죽어도 로그는 보존됨** (호스트 볼륨 마운트).
- 모든 폴더는 `.gitkeep` 으로 추적 (직접 또는 서브폴더 통해).
- 신규 서비스 추가 시 `log/<service>/` 폴더와 `.gitkeep` 을 반드시 추가.

#### Logrotate
- 호스트 `script/logrotate/<service>/<service>` → 컨테이너 `/etc/logrotate.d/<service>` 로 마운트.
- 정책: **`copytruncate` 방식** — 서비스 재시작 없이 로테이션 가능 (로테이션 순간 극소량 로그 누락 가능성은 트레이드오프).
- 보관 주기: 기본 30일 (php-fpm access는 7일, slow log는 90일 — 진단 우선).
- 적용 확인:
  ```bash
  docker exec -it <container> logrotate -d /etc/logrotate.d/<service>
  ```

---

### 3. SSL / HTTPS / Certbot 자동 갱신

#### 갱신 cron 의 진실 소스 (single source of truth)
- **`docker/nginx/Dockerfile` 한 곳만** 이 진실 소스입니다.
- `script/letsencrypt.sh` 는 초기 발급 전용 — cron 등록 라인 없음 (의도적 제거).
- 등록된 cron:
  ```cron
  0 5 * * 1 certbot renew --quiet --deploy-hook "nginx -t && nginx -s reload" >> /log/nginx/crontab_YYYYMMDD.log 2>&1
  ```

#### 컨테이너에서 nginx reload 는 `nginx -s reload` 만 사용
- `service nginx restart` / `systemctl reload nginx` 는 **사용 금지** — PID 1 = nginx 인 컨테이너에서는 동작 안 함 또는 전체 컨테이너 종료를 유발.
- `nginx -s reload` = master 프로세스에 `SIGHUP` 전송 → 새 워커 spawn 후 구 워커 graceful 종료.
- `nginx -t &&` 로 **설정 테스트 후에만** reload — 잘못된 conf 가 즉시 prod 반영되는 사고 차단.

#### cron 동작 확인
```bash
docker exec -it nginx-<service>-webserver bash -c "crontab -l"
docker exec -it nginx-<service>-webserver bash -c "ps aux | grep cron"
# 다음 실행 로그 확인
tail -f log/nginx/crontab_*.log
```

#### 첫 발급 절차 (요약)
1. HTTP 전용 nginx conf 로 컨테이너 기동
2. `docker exec -it <nginx-container> bash`
3. `/script/letsencrypt.sh` 실행 (webroot / domain / email 입력)
4. 정상 발급 후 `exit`
5. HTTPS conf 로 교체 → `docker compose restart`

---

### 3.5. 악성 봇 / DDoS 차단 — nginx-ultimate-bad-bot-blocker

기존 정적 `bad_bot.conf` (500+ 패턴 수동 관리) 는 폐기되고, 업스트림에서 6시간 단위로 갱신되는 [nginx-ultimate-bad-bot-blocker](https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker) 가 이를 대체합니다.

#### 빌드 시점 동작 (`docker/nginx/Dockerfile`)
1. `install-ngxblocker` / `setup-ngxblocker` / `update-ngxblocker` 다운로드
2. `install-ngxblocker -x` 실행 → 컨테이너 안에 초기 데이터 bake:
   - `/etc/nginx/conf.d/globalblacklist.conf` (모든 봇/스캐너/스크레이퍼 map 정의 — `$bad_bot`, `$bad_referer`, `$validate_referer` 등 변수 제공)
   - `/etc/nginx/bots.d/blockbots.conf` (server-level 차단 로직)
   - `/etc/nginx/bots.d/ddos.conf` (DDoS 패턴 차단)
   - `/etc/nginx/bots.d/{blacklist,whitelist}-*.conf` (운영자 커스텀용 빈 파일)

#### 런타임 동작
- 컨테이너 안 cron 이 **6시간마다** `update-ngxblocker` 실행 → globalblacklist.conf 만 최신화 후 `nginx -t && nginx -s reload` (graceful reload)
- 등록된 cron 라인:
  ```cron
  0 */6 * * * /usr/local/sbin/update-ngxblocker >> /log/nginx/ngxblocker_YYYYMM.log 2>&1 && nginx -t && nginx -s reload
  ```
- certbot 갱신 cron 과 같은 진실 소스(Dockerfile) — 운영 중 추가 sudo 작업 불필요

#### sample_nginx*.conf 의 통합 패턴
각 도메인 서버 블록의 옛 `if ($bad_bot) { return 403; }` 자리는 다음 **2-line include** 로 대체됩니다.
ngxblocker 의 `bots.d/` 9개 파일 중 server 컨텍스트에 들어가는 건 이 2개뿐:

```nginx
include /etc/nginx/bots.d/blockbots.conf;   # server-level `if ($bad_bot)` 검사 + 444 return
include /etc/nginx/bots.d/ddos.conf;        # server-level limit_conn / limit_req (봇만 적용)
```

> ⚠️ **`bots.d/{whitelist,blacklist}-*.conf`, `bots.d/bad-referrer-words.conf`,
> `bots.d/custom-bad-referrers.conf` 는 server 블록에 직접 include 하지 말 것.**
> 이 파일들은 `map`/`geo` 데이터 항목(`1.2.3.4 1;`, `~*pattern 1;`)을 담는 형식이라
> http 컨텍스트의 map/geo 블록 안에서만 유효하다. server 블록에 둔 채 운영자가
> 항목 한 줄만 추가해도 즉시 `nginx -t` 실패 → reload 거부 → 운영 다운.
> globalblacklist.conf 가 http 컨텍스트에서 이 7개 파일을 자동으로 include 하므로
> 운영자는 그냥 해당 파일에 항목만 추가하면 된다 — server 블록 수정 불필요.

#### 운영자가 직접 편집하는 파일 (도메인별 화이트/블랙리스트)
업스트림이 갱신하지 않는 사용자 커스텀 레이어 — `update-ngxblocker` 가 덮어쓰지 않음.
**파일에 항목만 추가하면 globalblacklist.conf 가 http 컨텍스트에서 자동 픽업한다.**
server 블록은 수정하지 않음:

| 파일 | 용도 | 형식 예시 |
|---|---|---|
| `/etc/nginx/bots.d/whitelist-ips.conf` | 절대 차단하지 않을 IP/CIDR | `203.0.113.0/24 0;` |
| `/etc/nginx/bots.d/whitelist-domains.conf` | 절대 차단하지 않을 referer 도메인 | `~*example\.com 0;` |
| `/etc/nginx/bots.d/blacklist-ips.conf` | 추가 차단 IP/CIDR | `198.51.100.5 1;` |
| `/etc/nginx/bots.d/blacklist-user-agents.conf` | 추가 차단 User-Agent | `~*MyEvilBot 1;` |
| `/etc/nginx/bots.d/custom-bad-referrers.conf` | 추가 차단 referrer 키워드 | `~*spam\-keyword 1;` |

> ⚠️ **`bots.d/blacklist-domains.conf` 는 globalblacklist.conf 가 include 하지 않으므로
> 항목을 추가해도 적용되지 않는다.** Dockerfile 이 빈 파일로 touch 만 해 둘 뿐이다.
> 추가 차단 referer 도메인은 `custom-bad-referrers.conf` 또는 `blacklist-user-agents.conf`
> (UA 기반) 로 처리하라.

수정 후 `docker exec -it nginx-<svc>-webserver bash -c "nginx -t && nginx -s reload"`.

#### 동작 검증
```bash
# 1) 알려진 봇 User-Agent 로 차단되는지 확인
curl -A "MJ12bot" -o /dev/null -s -w "%{http_code}\n" http://localhost/
# → 444 (또는 403) 가 정상

# 2) 정상 브라우저 UA 는 통과
curl -A "Mozilla/5.0" -o /dev/null -s -w "%{http_code}\n" http://localhost/
# → 200/3xx/4xx (502/503 가 아님)

# 3) 갱신 로그 확인
docker exec -it nginx-<svc>-webserver tail -20 /log/nginx/ngxblocker_$(date +%Y%m).log
```

#### 롤백 (긴급 시)
```bash
# 1) 컨테이너 안에서 globalblacklist.conf 일시 비활성화
#    (ngxblocker 는 -c /etc/nginx 옵션으로 설치되어 conf.d 가 아니라 /etc/nginx/ 직속에 있음.
#     단순히 파일을 옮기면 nginx.conf 의 include 라인이 file-not-found 로 nginx -t 실패 →
#     include 라인을 주석 처리하는 방식이 더 안전. nginx.conf 는 호스트 bind-mount 라
#     컨테이너 안 sed 가 호스트 파일까지 갱신해 다음 기동에서도 비활성 유지.)
docker exec -it nginx-<svc>-webserver sed -i \
    's|^\(\s*\)include /etc/nginx/globalblacklist.conf|\1# include /etc/nginx/globalblacklist.conf|' \
    /etc/nginx/nginx.conf
docker exec -it nginx-<svc>-webserver bash -c "nginx -t && nginx -s reload"
# 복귀 시: git 으로 nginx.conf 의 include 라인 복원 → reload

# 2) 또는 ngxblocker 마이그레이션 이전의 정적 bad_bot.conf 를 git 에서 복원
#    git log --diff-filter=D -- config/web-server/nginx/gunicorn/conf.d/bad_bot.conf  # 삭제 커밋 식별
#    git show <DELETE_COMMIT>^:config/web-server/nginx/gunicorn/conf.d/bad_bot.conf > config/web-server/nginx/gunicorn/conf.d/bad_bot.conf
#    그 다음 sample_nginx*.conf 를 git revert 로 되돌리고 컨테이너 conf.d 로 재마운트 / reload
```

---

### 4. OS-level 동시 조정 권장

`backlog=2048` (gunicorn/uwsgi/php-fpm) 가 실제 효과를 내려면 커널 파라미터도 함께 올려야 합니다.

```bash
# /etc/sysctl.d/99-devspoon-web.conf
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.ip_local_port_range = 10000 65535
vm.overcommit_memory = 1            # Redis 권장
fs.file-max = 200000

# 적용
sudo sysctl --system
```

- ulimit: docker daemon 단에서 `default-ulimits` 로 `nofile=65536` 권장.
- 8 GB RAM 한계: swap 2-4 GB 확보(메모리 스파이크 시 OOM 방어용).

---

### 5. 운영 시 자주 마주치는 이슈

| 증상 | 의심 지점 | 대응 |
|---|---|---|
| 컨테이너 OOM Kill | 워커 메모리 합 > 6 GB | `docker stats` 로 RSS 추이 확인 → workers 또는 max_requests 하향 |
| 갑작스러운 워커 재시작 | `max_requests` 도달 또는 `harakiri/timeout` | error 로그에서 "Worker timeout" 확인. 장기 작업은 celery 로 분리 |
| 502 Bad Gateway 간헐 | upstream 종료 시점 vs nginx keepalive | gunicorn `keepalive` 가 nginx `keepalive_timeout` 보다 짧은지 확인 |
| celery 메모리 증가 | prefork 워커 메모리 누수 | `--max-tasks-per-child=2000` 동작 확인. 라이브러리(특히 numpy/pandas) 의 메모리 fragmentaion 가능성 |
| logrotate 미동작 | 호스트 경로 오타 / cron 미설치 | `script/logrotate` (s 주의) 폴더명, 컨테이너 cron 데몬 동작 확인 |
| certbot 갱신 실패 | webroot 권한 / DNS 변경 / 80 포트 차단 | `/log/nginx/crontab_*.log` 확인. 수동 dry-run: `certbot renew --dry-run` |
| `preload_app=True` 후 DB 에러 | fork 후 DB 커넥션 공유 | `post_fork` hook 에서 `connections.close_all()` (Django) 또는 engine 재생성 |

---

### 6. 배포 절차 (수동 stop/start)

```bash
# 1. 신규 코드 pull
git pull origin main

# 2. 변경된 도커파일이 있으면 빌드 (없으면 생략)
cd compose/web_service/nginx_<service>
docker compose build --no-cache <service>-app   # 필요한 서비스만

# 3. 중단
docker compose stop

# 4. 시작
docker compose --profile celery --profile redis up -d

# 5. 헬스 확인
docker compose ps
docker compose logs --tail=100 -f <service>-app

# 6. 외부 헬스체크
curl -fsS https://<domain>/health || echo "FAIL"
```

> **`docker compose down` 은 사용하지 말 것** — 일부 네트워크/볼륨 메타가 같이 제거되어 SSL/redis 데이터 재구성 비용이 발생할 수 있습니다.

---

### 7. 보안 / 운영 체크리스트

- [ ] `.env` 의 비밀값 (`REDIS_PASSWORD`, `FLOWER_ID`, `FLOWER_PWD`) 은 git 에 커밋하지 않을 것. `.gitignore` 의 `**/.env` + `!**/.env.example` 패턴 확인 (§0.5.1). `CELERY_BROKER_URL` 은 .env 에 없음 — REDIS_PASSWORD 로부터 compose 가 합성 (§0.5.3).
- [ ] `flower(5555)` 포트는 외부 노출 시 nginx basic auth 또는 IP allowlist 적용 (`FLOWER_BASIC_AUTH` 는 이미 강제되어 있지만 추가 레이어 권장). `redis-stats` 는 제거되었으므로 별도 모니터링 필요 시 RedisInsight/redis_exporter 도입 (§0.5.7).
- [ ] redis 는 컨테이너 내부 네트워크 전용(외부 포트 미노출 상태가 기본 — 유지 권장). `protected-mode yes` + `requirepass` 가 강제되어 동일 네트워크 컨테이너도 인증 필요 (§0.5.2).
- [ ] Python 베이스 이미지 빌드 시 `docker build --build-arg PYTHON_SHA256=<official>` 또는 ARG default 값(`docker/gunicorn/Dockerfile`) 이 python.org 공식 해시와 일치하는지 분기 1회 재확인 (§0.5.4).
- [ ] `docker/nginx/Dockerfile` 의 cron 시간(매주 월요일 05:00)이 트래픽 한산 시간대인지 운영 환경 기준으로 재검토.
- [ ] 로그 디스크 모니터링 — `df -h log/` 가 80% 도달 시 알림.
- [ ] `ufw` / 클라우드 방화벽에서 80/tcp, 443/tcp 만 외부 노출, 그 외 모든 포트 차단 (flower 5555 는 내부망에서만).
- [ ] OS 시간 동기화(`chrony` 또는 `systemd-timesyncd`) — certbot/cron/로그 타임스탬프 정합성.

---

### 8. Python 의존성 / uv 정책 — "컨테이너 안에서는 가상환경 미사용"

본 프로젝트는 `www/django_sample` 의 Python 의존성을 **uv** 로 관리하지만, 컨테이너 내부에서는 의도적으로 **별도 가상환경(`.venv`)을 만들지 않습니다.** 컨테이너 자체가 격리 단위이므로 venv 는 불필요한 중복 계층이며, 트러블슈팅을 복잡하게 만듭니다.

#### 동작 원리

- `docker/gunicorn/Dockerfile`, `docker/uwsgi/Dockerfile` 에 다음 ENV 가 박혀 있음:
  ```
  UV_PROJECT_ENVIRONMENT=/usr/local
  UV_LINK_MODE=copy
  UV_COMPILE_BYTECODE=1
  UV_NO_CACHE=1
  ```
- 이로 인해 컨테이너 안에서의 `uv sync` 는 `.venv` 를 만들지 않고 **`/usr/local/lib/python3.14/site-packages` (시스템 Python)** 에 직접 설치.
- compose `command:` 는 `uv run` 을 거치지 않고 시스템 바이너리(`gunicorn`, `daphne`, `uwsgi`, `celery`) 를 그대로 호출.
- `--inexact` 플래그로 Dockerfile 이 사전 설치한 패키지(fastapi/sqlalchemy/wheel 등) 가 제거되지 않도록 보호.

#### 운영자가 얻는 이점

| 항목 | venv 사용 시 | 본 프로젝트 (시스템 설치) |
|---|---|---|
| import 디버그 | `uv run python -c "import django"` | `python -c "import django"` |
| 패키지 목록 | `uv pip list --python .venv/bin/python` | `pip list` |
| 호스트 디렉터리 | `www/<project>/.venv/` 가 호스트에 생성됨 | 호스트는 소스만, 깨끗하게 유지 |
| cross-volume hardlink | 종종 충돌 → `UV_LINK_MODE=copy` 우회 필요 | 동일 layer 안이라 무영향 |
| 한 컨테이너에 두 venv | 가능, 혼란 | 단일 시스템 site-packages → 모호함 없음 |

#### 개발 머신(호스트) 에서는 정반대

`UV_PROJECT_ENVIRONMENT` 가 호스트에는 없으므로, 개발자는 `cd www/django_sample && uv sync` 만으로 자동으로 `.venv` 가 만들어집니다. 호스트와 컨테이너가 같은 `pyproject.toml` 을 쓰지만 설치 위치만 다르게 가져갑니다.

#### 의존성 추가/갱신 워크플로우

```bash
# 호스트(개발 머신)에서:
cd www/django_sample
uv add django-celery-beat            # 런타임 deps 추가 → pyproject.toml + uv.lock 갱신
uv add --dev pytest-mock             # 개발 deps 추가
uv lock                              # 락만 재생성 (필요 시)

# 변경 사항을 커밋:
git add pyproject.toml uv.lock
git commit -m "deps: add django-celery-beat"

# 컨테이너 재기동 → 시작 시점에 uv sync 가 자동 실행되어 시스템 Python 에 반영:
docker compose stop && docker compose up -d
```

#### 트러블슈팅 예시

```bash
# 1) 컨테이너 안에서 패키지 설치 상태 확인 — venv 활성화 불필요
docker exec -it gunicorn-app pip list | grep -i django

# 2) Django 환경에서 즉시 ORM 셸 진입
docker exec -it gunicorn-app python manage.py shell

# 3) uv sync 가 실제로 어디에 설치하는지 확인
docker exec -it gunicorn-app uv pip list --system
docker exec -it gunicorn-app python -c "import django; print(django.__file__)"
# → /usr/local/lib/python3.14/site-packages/django/__init__.py
```

#### 주의 — extras race 방지 원칙 유지

같은 compose 스택의 모든 파이썬 컨테이너(app + celery + celerybeat) 는 **반드시 동일한 extras 조합** 으로 `uv sync` 합니다. 시스템 site-packages 가 공유되므로, 한 컨테이너가 다른 extras 로 sync 하면 다른 컨테이너의 패키지가 제거될 수 있습니다. `--inexact` 가 1차 안전망이지만 extras 조합은 일관되게 유지하세요.

---

### 9. 변경 시 영향 범위 매트릭스

| 변경 | 재빌드 필요? | 컨테이너 재기동 필요? |
|---|---|---|
| `docker/<service>/Dockerfile` | ✅ `docker compose build` | ✅ |
| `config/app-server/*/...` (conf.py, ini) | ❌ (볼륨 마운트) | ✅ (워커 재로드) |
| `config/web-server/nginx/...` (별도 관리) | ❌ | nginx 컨테이너만 `nginx -s reload` |
| `compose/.../docker-compose.yml` | 변경 종류에 따라 | ✅ |
| `script/logrotate/*` | ❌ | ❌ (다음 cron tick 부터 적용) |
| `script/letsencrypt.sh` | ❌ | ❌ |
| `script/test/*` | ❌ | ❌ (호스트 수동 실행 검증 자산, 운영 무관) |

---

### 10. 테스트 / 검증 인프라 (`script/test/`)

`script/test/` 의 스크립트는 **운영 이미지/스택과 무관**합니다. Dockerfile / docker-compose 어느 곳에서도 참조되지 않으며 컨테이너 안에 들어가지도 않습니다. 개발자가 호스트(WSL2 Ubuntu + Docker 가정)에서 직접 실행해 정합성과 회귀를 검증하는 자산입니다. **폴더를 삭제해도 운영 서비스 동작에는 영향이 없습니다** — 회귀 검증 편의 자산일 뿐입니다.

#### 구성 (2개 파일)

| 파일 | 종류 | 소요 | 컨테이너 변경? |
|---|---|---|---|
| `preflight.sh` | 환경 사전 점검 (read-only) | ~30 초 | 없음 |
| `verify-ngxblocker.sh` | ngxblocker 종단간 자동 검증 | 1–3 분 | gunicorn 스택을 down → up + 임시 conf 추가/제거 (스크립트가 자체 cleanup) |

---

#### 10.1 `preflight.sh` — 새 환경 셋업 시 사전 점검

테스트 또는 운영 셋업 시작 전 호스트 환경이 작업 요건을 만족하는지를 30 초 안에 확인하는 **read-only** 스크립트입니다. 어떤 파일도 만들거나 변경하지 않고, 컨테이너도 띄우지 않습니다.

**사용 방법**

```bash
cd /path/to/devspoon-web     # 리포지토리 루트
bash script/test/preflight.sh
```

종료 코드: `0` = PREFLIGHT PASS(테스트/배포 시작 가능), `1` = PREFLIGHT FAIL(미충족 항목 존재 — 화면의 `[MISS]` 라인 수정 후 재실행).

**언제 실행하는가**

1. **새 dev 환경(WSL2 / 클라우드 VM) 셋업 직후** — 필수 도구가 빠지지 않았는지 확인.
2. **OS / Docker 메이저 업데이트 직후** — `docker compose v2` 마이그레이션 같은 회귀 점검.
3. **신규 팀원 온보딩 첫 30 분** — "왜 안 돼요?" 라운드트립을 줄임.
4. **CI 워크플로의 첫 step 으로 호출** — 의존성 가시화 (이 스크립트가 환경 문서 역할).

**무엇을 확인하는가** (4개 카테고리)

| 카테고리 | 항목 예시 | 실패 시 |
|---|---|---|
| `[1] Required tools` | `docker`(>=24), `docker compose`(v2), `jq`, `curl`, `openssl`, `wrk`(optional) | `[MISS]` — 해당 도구 설치 필요 |
| `[2] Repository files` | 5개 스택 각 `.env`(gunicorn / uvicorn / daphne / uwsgi / **nginx_php-7.3 / nginx_php-8.4**), Dockerfile 4종(**php-fpm 은 7.3/8.4 둘 다**), entrypoint, `pyproject.toml`, `script/letsencrypt.sh` | `[MISS]` — 리포지토리 무결성 깨짐. clone 재시도 또는 git status 확인 |
| `[3] Design invariants` | `script/logrotate` 폴더명 (오타 'loglotate' 아님), `log/.gitkeep × 11`, `pyproject.toml` PEP 621 여부, `UV_PROJECT_ENVIRONMENT=/usr/local`, FROM 베이스 정합성, `service nginx restart` 회귀 부재, `uwsgi.ini py-autoreload=0` 등 | `[MISS]` — 의도된 디자인 결정 깨짐. 자세한 근거는 §0, §6, §8 참조 |
| `[4] Host environment` | WSL2 여부, 디스크 여유 20 GB+, `net.core.somaxconn` 4096+ | `[WARN]` — informational. 운영 시 권장이지만 dev 에서는 무시 가능 |

`[3]` 의 `service nginx restart` 검사는 컨테이너 안에서 `service` 명령으로 nginx 를 restart 하면 PID 1 = nginx 인 환경에서 컨테이너가 통째로 종료되는 사고를 방지하기 위한 정적 grep 입니다.

---

#### 10.2 `verify-ngxblocker.sh` — nginx 봇 차단 종단간 검증

[nginx-ultimate-bad-bot-blocker](https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker) 의 다운로드, 통합, 차단 동작이 실제로 작동하는지를 종단간으로 자동 검증합니다. **gunicorn 스택**(`compose/web_service/nginx_gunicorn`)을 테스트 베드로 사용합니다 — PHP 스택은 사용하지 않습니다(어차피 nginx 컨테이너 이미지는 모두 동일하므로 한 스택에서만 검증해도 충분).

**사용 방법**

```bash
cd /path/to/devspoon-web     # 리포지토리 루트
bash script/test/verify-ngxblocker.sh
```

종료 코드: `0` = ALL CHECKS PASSED, `1` = 한 개 이상 실패(화면의 `[FAIL]` 라인 확인). PASS 시 마지막 줄에 녹색 `ALL CHECKS PASSED` 가 출력됩니다.

**중요한 부작용 — 실행 직후 상태**

이 스크립트는 read-only 가 아닙니다. 다음 순서로 환경을 만집니다:

1. **gunicorn 스택을 `docker compose down -v --remove-orphans`** 후 `up -d webserver redis` — 검증을 위해 깨끗한 상태에서 시작. 기존에 다른 gunicorn 컨테이너가 떠 있었다면 종료되며, 볼륨도 함께 제거됩니다.
2. **컨테이너 안에 임시 conf** (`/etc/nginx/conf.d/zz_blocker_test.conf`) **추가** — `Host: blocker.test` 매칭 server 블록. 스크립트 종료 직전에 `Cleanup` 단계에서 제거 + reload 합니다.
3. **임시 로그 파일** (`/log/nginx/blocker_test_access.log`, `blocker_test_error.log`) — 호스트 볼륨에 남습니다 (필요 시 수동 정리).
4. **수동 `update-ngxblocker -c /etc/nginx` 호출** — globalblacklist.conf 를 최신화하며 mtime 이 갱신됩니다.

운영 중인 호스트에서 직접 돌리면 일시적으로 gunicorn 스택 다운타임이 발생하므로 **운영 트래픽이 있는 서버에서는 정비 시간대에만 실행**하세요.

**언제 실행하는가**

| 트리거 | 이유 |
|---|---|
| `nginx.conf` 의 `limit_conn_zone` / `limit_req_zone`(`$bot_iplimit`) 같은 zone 이름·key·size·rate 변경 | rate-limit 정책이 봇 차단 통합에 회귀를 일으킬 수 있음 |
| `bots.d/ddos.conf` 또는 `globalblacklist.conf` 의 **수동** `update-ngxblocker` 실행 직후 | 자동 cron(6시간) 외 수동 갱신은 회귀 가능성이 큼 |
| `sample_nginx*.conf` 의 ngxblocker include 라인(`blockbots.conf` / `ddos.conf`) 위치 변경 또는 다른 `bots.d/*` 파일 추가 | server 컨텍스트 include 가 올바른 위치에 들어갔는지 확인 |
| `docker/nginx/Dockerfile` 재빌드 (install-ngxblocker, ca-certificates, cron 셋업 등 단계 변경) | 빌드 시점 bake-in 산출물이 모두 존재하는지 확인 |
| 6 개월 이상 빌드/검증 공백 후 재가동 | 업스트림(`mitchellkrogza/nginx-ultimate-bad-bot-blocker`) 의 포맷이 미세하게 바뀌어 grep 패턴이 깨질 수 있음 |

**검증 단계 (Step A–E)**

| Step | 무엇을 보는가 |
|---|---|
| **A** 스택 기동 | `docker compose down -v` → `up -d webserver redis`, `nginx -t` 통과 |
| **B** 다운로드 산출물 | `globalblacklist.conf` ≥ 400 KB, 1000+ 봇 regex 패턴, 알려진 봇 8 종(MJ12, Ahrefs, Semrush, DotBot, BLEX, Scrapy, nikto, sqlmap) 포함, `bots.d/` 9 파일 모두 존재 |
| **C** nginx 통합 | `nginx.conf` 가 `globalblacklist.conf` 를 1회 include, `$bad_bot` 변수 정의, `nginx -t` syntax/test OK, master + worker ≥ 2 |
| **D** cron / 갱신 | crontab 에 `update-ngxblocker -c /etc/nginx` 라인 등록, cron 데몬 실행, 수동 update 실행 후 파일 정상 + reload 후 워커 정상 |
| **E** 종단간 차단 | 임시 server 블록(`blocker.test`) 추가 후 — Mozilla UA → 200, 봇 UA 4종(MJ12 / Ahrefs / Semrush / BLEX) → 444 / 000 / 403, bad referer(semalt.com) 차단(옵션), 액세스 로그 기록 |

`E-4` 의 봇 UA 응답 코드가 `444` 가 아니라 `000` 으로 보이는 경우가 있는데, 이는 nginx 가 응답 없이 연결을 닫아 curl 이 응답을 못 받았다는 의미로 동일한 PASS 입니다.

---

#### 시나리오별 빠른 가이드

| 시나리오 | 실행 명령 |
|---|---|
| 새 dev 환경 셋업 후 첫 진단 | `bash script/test/preflight.sh` |
| OS / Docker 업데이트 직후 회귀 점검 | `bash script/test/preflight.sh` |
| `nginx.conf` 의 rate-limit / `bots.d/*` 변경 후 | `bash script/test/verify-ngxblocker.sh` |
| `docker/nginx/Dockerfile` 재빌드 후 | `bash script/test/verify-ngxblocker.sh` |
| 두 스크립트를 연달아 (셋업 → 봇 차단 검증) | `bash script/test/preflight.sh && bash script/test/verify-ngxblocker.sh` |

새로운 회귀 검증 자산이 필요해지면 같은 폴더에 `verify-<topic>.sh` 또는 `preflight-<topic>.sh` 네이밍으로 추가하면 일관성이 유지됩니다.

---

## Community

- **Website** : Owner's personal website is [devspoon.com](devspoon.com)

## Partners and Users

- Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com

<!-- Markdown link & img dfn's -->

[devspoon.github.io]: https://github.com/devspoons/devspoon.github.io
[wiki]: https://github.com/yourname/yourproject/wiki
[youtube]: https://www.youtube.com/
[inflearn]: https://www.inflearn.com/
[bluebamus.github.io]: bluebamus.github.io
[devspoons.github.io]: devspoons.github.io
