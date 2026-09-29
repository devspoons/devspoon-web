# devspoon-web

**[English](README.md)** · [한국어](README-kr.md)

This open source project offer docker that three kind of web or API service solutions by php, gunicorn, uwsgi based on nginx server.
You can easily create custom configuration files for nginx using a shell script.
Supports https and certbot auto-extension script.
there are default security settings in the nginx config file.
docker-compose allows you to easily install and operate multiple domain servers on one server.
For server caches, docker-compose supports installing and connecting redis and redis-state.
Anyone can install web services easily using docker and docker-compose.
Af you want to use python and php service at same time, this solution can help you better.

## Introducing "Devspoon-Projects"

- We provide an open source infrastructure integration solution that can easily service Python, Django, PHP, etc. using docker-compose. You can install the commercial-level customizable nginx service and redis at once, and install and manage more services at once. If you are interested, please visit [Devspoon-Projects](https://github.com/devspoon/Devspoon-Projects).

## Official guide document

- preparing...

## Features

- **Support to make configuration files for each service(conf, certbot)** : You can use a shell script to generate conf files for https and proxy settings in nginx. Supports a script to restart docker using crontab to complete certbot authentication of the docker container.

- **Efficiently dockerfile configuration for development and service operation** : The log folder is interlocked by "volumes" in docker-compose.yml so that user can can be tracked problems even when the docker container is stopped. Webroot, nginx config, etc. are frequently modified during development so these are interlocked by "volumes"

- **Provide reverse proxy function** : Multiple web and app services can be provided through one nginx with php or python and services can be provided simultaneously. A shell script is provided to easily create a proxy config file so that it can be integrated with the web UI of other services.

- **Provides easy distributed service operation method** : You can use multiple web servers through proxy, and you can use multiple app servers on one web server.

- **Easy service changes using Docker-compose** : In docker-compose, various configuration items are defined and commented out. By deleting comments or adjusting your desired settings, you can easily create an environment that suits your purposes.

- **log file collection** : Log files for all services are stored in log/<service> and can be monitored even after container termination.

- **redis and ssl** : Information such as configuration files, data, and keys for Redis and SSL are attached as volumes to the redis and ssl folders in docker-compose, so they can be reused when the container is terminated and restarted.

- **Ready-to-run sample apps** : Django (`django_sample`), FastAPI (`fastapi_sample`), Flask (`flask_sample`), and PHP (`php_sample`) live under `www/` so each of the six stacks (gunicorn / uvicorn / uwsgi / daphne / php-7.3 / php-8.4) can be brought up immediately after `git clone`. Samples are domain-agnostic — bind to `localhost` first, swap to your domain when ready.

- **Worker privilege drop (`www-data`)** : gunicorn / uvicorn / uwsgi / php-fpm workers all run as `www-data` (uid 33) — the container boots as root (for `uv sync` etc.) but workers are dropped to least privilege. The host source tree bind-mounted at `/www` is never chowned: the only writable paths are the named volume `/data` (SQLite, `SQLITE_PATH`), which the app `command` chowns to `www-data`, and the celery log directories, which the celery / celery-beat `command`s chown to `www-data` before startup (§0.6.2). uwsgi master uses `uid/gid = www-data`; gunicorn arbiter stays root and forks workers via setuid; celery / celery-beat run with `--uid/--gid www-data`. Exception: the daphne process has no privilege-drop option and runs as root inside its container.

- **Secret separation (`.env-example`)** : Every stack ships a tracked `.env-example` (`compose/web-service/nginx_*/.env-example`), while the actual `.env` is gitignored. Copy it to `.env`, then generate the empty secrets (`DJANGO_SECRET_KEY` / `REDIS_PASSWORD` / `FLOWER_PWD`) with `script/lib/django_secrets.sh` (`ensure_env_secrets`, §0.6.1); never commit the live file. `${VAR:?}` checks in the compose files fail-fast if a required secret is missing.

- **Bot blocker auto-update + supply-chain hardening** : Integrates [nginx-ultimate-bad-bot-blocker](https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker). Container cron refreshes the blocklist every 6 hours. The installer scripts themselves are pinned to a fixed commit SHA and verified with sha256 at build time — no `master` floating reference.

- **Dynamic gzip compression** : All four nginx config directories (gunicorn / uvicorn / uwsgi / php; daphne reuses gunicorn's) enable `gzip on` with level 5, `gzip_min_length 1024`, and `gzip_proxied any` for JSON/HTML/CSS/JS/XML/SVG payloads. Proxy-passed backend responses are compressed too. Pre-compressed `.gz` static assets are served via `gzip_static on`.

## Considerations

- **No DB service** : This open source does not provide DB as docker to suggest stable operation. It is recommended to install it on a real server and access it using a network, such as port 3306. We hope that this will be done for distributed services as well. We hope that this will be consider for distributed services as well.

- **Development-oriented docker service** : This open source is designed for focused on development-oriented rather than perfect docker container distribution and is suitable for startups or new service development teams with frequent initial modifications and tests.

- **Considering on-premise servers** : This solution is built for on-premises servers. However, since it is currently being used as a test and commercial service in OCI (Oracle Cloud Infrastructure), it can be used in environments such as AWS and GCP without problems.

## Operations Guide

The operations guide is maintained as a series under [`docs/operations-guide/nginx-hardening/`](docs/operations-guide/nginx-hardening/). Start at [**OPS-GUIDE-001 Master Index**](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-001-master-index.md), which holds the threat model, the priority matrix, the quarterly roadmap and the series index. Each sub-guide covers one domain and is updated independently:

| No. | Document | Area covered |
| --- | --- | --- |
| OPS-GUIDE-001 | [Master Index](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-001-master-index.md) | Threat model, priority matrix, roadmap, common rollback, series index, review/update policy |
| OPS-GUIDE-002 | [TLS / certificate operations](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-002-tls-certificate-lifecycle.md) | Certificate expiry monitoring, HSTS preload, Let's Encrypt account backup |
| OPS-GUIDE-003 | [Application-layer defence](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-003-application-layer-defense.md) | WAF (ModSecurity + OWASP CRS), fail2ban, phased CSP rollout |
| OPS-GUIDE-004 | [Container / image security](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-004-container-and-image-security.md) | Resource limits, read-only filesystem, image vulnerability scanning, SBOM/signing, egress filtering, backend isolation |
| OPS-GUIDE-005 | [Observability / logs / metrics](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-005-observability-and-operations.md) | Log rotation, observability stack, custom error pages, audit log immutability, secrets management, backup/DR |
| OPS-GUIDE-006 | [Edge / network](docs/operations-guide/nginx-hardening/2026-05-15-OPS-GUIDE-006-edge-and-network.md) | HTTP/3, real_ip, SSL mount scope, Slowloris, CONTINUATION flood, DDoS playbook |

Each document has the same seven sections: rationale (Why) → current state → implementation steps with configuration snippets → how to verify → monitoring → rollback → common pitfalls. Put the series ID in the PR title (`OPS-GUIDE-003: add WAF Phase 2 exclusion`) so quarterly reviews stay traceable.

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
       There are 2 shell scripts (nginx_http_conf.sh, nginx_https_conf.sh)
         - nginx_http_conf.sh  → sample_nginx_http.conf  → conf.d/<name>_php_ng_http.conf
         - nginx_https_conf.sh → sample_nginx_https.conf → conf.d/<name>_php_ng_https.conf
       Use "chmod +x xxxx.sh" command, you activate shell script and run. then it make conf file
       nginx's a conf file will be in conf.d folder. HTTP output always ends with "_http".
       Options: "./nginx_http_conf.sh -h" (no manual path escaping needed)
       ```

       ```
       Shell script required informations like bellow
       webroot : ex -> shop_kings
       domain : ex -> xxxx.com
       portnumber : ex -> 80
       appname : ex -> php-app-7.3   (for the PHP 7.3 stack)
                  or  php-app-8.4   (for the PHP 8.4 stack)
                  → must match container_name in compose/web-service/nginx_php-<ver>/docker-compose.yml
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
       Before first start, create .env and generate its secret (repository root,
       <ver> = 7.3 or 8.4, §0.6.1):
           cp compose/web-service/nginx_php-<ver>/.env-example compose/web-service/nginx_php-<ver>/.env
           bash -c '. script/lib/django_secrets.sh && ensure_env_secrets compose/web-service/nginx_php-<ver>/.env'
       (REDIS_PASSWORD is empty in .env-example; the helper fills it with a random value.)

       Then move to the stack folder and execute docker-compose.yml
       (--build rebuilds the image after an upgrade or a Dockerfile change):
           PHP 7.3 →  cd compose/web-service/nginx_php-7.3
           PHP 8.4 →  cd compose/web-service/nginx_php-8.4
           docker compose up -d --build
       redis is gated by "profiles: redis" in PHP stacks — start it via:
           docker compose --profile redis up -d

       Cannot run both stacks at once: both bind host ports 80/443.
       To switch versions: "docker compose --profile redis stop" in the running stack first
       (a plain "stop" leaves the profile-gated redis running), then "up -d --build" in the other.
       Use stop, not down — see §6 (never "down -v").
       ```

       > **The PHP `.env-example` has a different variable set from the Python stacks.** PHP stacks
       > use a simplified set: `LOG_DRIVER`, `LOG_OPT_MAXF`, `LOG_OPT_MAXS`, `REDIS_PASSWORD`,
       > `ULIMIT_NOFILE_SOFT/HARD`.
       > The Python stack's `PROJECT_DIR / WORKERS / PROJECT_NAME / FLOWER_* / GUNICORN_PORT` are not
       > defined for PHP. Instead of `PROJECT_DIR`, the fixed webroot is whatever `root /www/php_sample`
       > in the nginx sample conf points at (`www/php_sample/`).
       > To swap in a new php project, create `www/<myphp>/` and change only `root /www/<myphp>` in the
       > nginx conf — no compose variable changes needed.

   - Gunicorn service

     - **Gunicorn service installation [nginx for gunicorn]**

       ```
       In config/web-server/nginx/gunicorn
       There are 2 shell scripts (nginx_http_conf.sh, nginx_https_conf.sh)
       Use "chmod +x xxxx.sh" command, you activate shell script and run. then it make conf file
       nginx's a conf file will be in conf.d folder (<name>_gunicorn_ng_http.conf / <name>_gunicorn_ng_https.conf)
       Options: "./nginx_http_conf.sh -h" (no manual path escaping needed)
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
       In config/app-server/gunicorn/
         - gunicorn.conf.py  → Gunicorn settings (workers, bind, user="www-data", group="www-data", ...)

       The run.sh / make_run.sh pattern is no longer used. The gunicorn-app service in
       docker-compose.yml runs this directly:

         command: bash -c "uv sync --inexact --extra gunicorn --extra celery \
                  && { [ ! -f manage.py ] || python manage.py migrate --noinput; } \
                  && { [ ! -f prestart.sh ] || bash prestart.sh; } \
                  && chown -R www-data:www-data /data \
                  && exec gunicorn -c /gunicorn/gunicorn.conf.py"

       That single line covers all of:
         (1) uv syncs the [gunicorn,celery] extras from pyproject.toml into the container's
             site-packages (no-virtualenv policy, §8)
         (2) one DB initialisation before the server starts — migrate for Django (manage.py),
             prestart.sh for non-Django (flask/fastapi). App service only, §0.6.3
         (3) chowns only the writable path, the named volume /data (SQLite), to www-data —
             the host source tree at /www is never chowned (§0.6.2)
         (4) starts gunicorn with /gunicorn/gunicorn.conf.py (workers as user="www-data")
       No separate run.sh is needed.

       To swap in a new project, change PROJECT_DIR in .env and nothing else.
       ```

     - **Run docker-compose.yml**

       ```
       Before first start, create .env and generate its secrets (repository root, §0.6.1):
           cp compose/web-service/nginx_gunicorn/.env-example compose/web-service/nginx_gunicorn/.env
           bash -c '. script/lib/django_secrets.sh && ensure_env_secrets compose/web-service/nginx_gunicorn/.env'
       Then replace FLOWER_ID (CHANGE_ME_FLOWER_USER). CELERY_BROKER_URL is no longer stored in .env —
       it is composed from REDIS_PASSWORD at compose time (SSOT, see §0.5.3).

       Then move to the stack folder and run docker-compose.yml
       (--build rebuilds the images after an upgrade or a Dockerfile / uv.lock change, §0.6.4):
           cd compose/web-service/nginx_gunicorn
           docker compose up -d --build
       For celery / celery-beat / flower: "docker compose --profile celery up -d".
       (redis-stats has been removed — see §0.5.7)
       ```

   - UWSGI service

     - **UWSGI service installation [nginx for uwsgi]**

       ```
       In config/web-server/nginx/uwsgi
       There are 2 shell scripts (nginx_http_conf.sh, nginx_https_conf.sh)
       Use "chmod +x xxxx.sh" command, you activate shell script and run. then it make conf file
       nginx's a conf file will be in conf.d folder (<name>_uwsgi_ng_http.conf / <name>_uwsgi_ng_https.conf)
       Options: "./nginx_http_conf.sh -h" (no manual path escaping needed)
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
         - uwsgi_conf.sh  → uwsgi.ini generator (asks for domain / chdir / module / ...)
         - uwsgi.ini      → the generated file (includes the master's uid=33 gid=33 privilege drop)

       The run.sh / make_run.sh pattern is no longer used. The uwsgi-app service in
       docker-compose.yml runs this directly:

         command: bash -c "uv sync --inexact --extra uwsgi --extra celery \
                  && { [ ! -f manage.py ] || python manage.py migrate --noinput; } \
                  && { [ ! -f prestart.sh ] || bash prestart.sh; } \
                  && chown -R www-data:www-data /data \
                  && exec uwsgi --ini /application/uwsgi.ini"

       That single line covers (1) syncing uv's [uwsgi,celery] extras, (2) one DB initialisation
       before the server starts (migrate or prestart.sh, §0.6.3), (3) chowning only the /data volume
       to www-data — the source tree at /www is untouched, and (4) starting the uwsgi master
       (uid/gid = www-data). No separate run.sh is needed.

       To swap in a new project, change PROJECT_DIR in .env and nothing else.
       ```

     - **Run docker-compose.yml**
       ```
       Before first start, create .env and generate its secrets (repository root, §0.6.1):
           cp compose/web-service/nginx_uwsgi/.env-example compose/web-service/nginx_uwsgi/.env
           bash -c '. script/lib/django_secrets.sh && ensure_env_secrets compose/web-service/nginx_uwsgi/.env'
       Then replace FLOWER_ID. CELERY_BROKER_URL is no longer in .env (see §0.5.3).

       Then move to the stack folder and run docker-compose.yml
       (--build rebuilds the images after an upgrade or a Dockerfile / uv.lock change, §0.6.4):
           cd compose/web-service/nginx_uwsgi
           docker compose up -d --build
       For celery / celery-beat / flower: "docker compose --profile celery up -d".
       (redis-stats has been removed — see §0.5.7)
       ```

   - Uvicorn (ASGI) service

     > The §0.5.9 sync added `config/web-server/nginx/uvicorn/` (the whole folder) and
     > `config/app-server/uvicorn/gunicorn_uvicorn.conf.py`, so this stack can now generate and run
     > its nginx side properly. Earlier versions had only the `compose/.../nginx_uvicorn/` stack with
     > no nginx conf folder, leaving no way to create a domain conf.

     - **Uvicorn service installation [nginx for uvicorn]**

       ```
       In config/web-server/nginx/uvicorn
       There are 2 shell scripts (nginx_http_conf.sh, nginx_https_conf.sh)
         - nginx_http_conf.sh  → sample_nginx_http.conf  → conf.d/<name>_uvicorn_ng_http.conf
         - nginx_https_conf.sh → sample_nginx_https.conf → conf.d/<name>_uvicorn_ng_https.conf
       Use "chmod +x xxxx.sh" command, you activate shell script and run.
       ```

       ```
       Shell script required informations like bellow
       webroot : ex -> fastapi_sample           (or django_sample for ASGI Django)
       domain : ex -> xxxx.com
       portnumber : ex -> 80
       appname : ex -> uvicorn-app
                   → must match container_name in compose/web-service/nginx_uvicorn/docker-compose.yml
       serviceport : ex -> 8000
       filename : ex -> xxxx (it's the name for nginx's conf file)
       ```

     - **Uvicorn service installation [uvicorn application]**

       ```
       In config/app-server/uvicorn there are TWO config files:
         - uvicorn.conf.py           → for starting uvicorn directly
         - gunicorn_uvicorn.conf.py  → the gunicorn + UvicornWorker pattern (prefork ASGI, many workers)
       Both load via UV_PROJECT_ENVIRONMENT=/usr/local (no-virtualenv policy, §8).
       ```

     - **Run docker-compose.yml**

       ```
       Before first start, create .env and generate its secrets (repository root, §0.6.1):
           cp compose/web-service/nginx_uvicorn/.env-example compose/web-service/nginx_uvicorn/.env
           bash -c '. script/lib/django_secrets.sh && ensure_env_secrets compose/web-service/nginx_uvicorn/.env'
       Then replace FLOWER_ID. CELERY_BROKER_URL is composed from REDIS_PASSWORD (§0.5.3).

       Then move to the stack folder and run docker-compose.yml
       (--build rebuilds the images after an upgrade or a Dockerfile / uv.lock change, §0.6.4):
           cd compose/web-service/nginx_uvicorn
           docker compose up -d --build
       For celery / celery-beat / flower: "docker compose --profile celery up -d".
       ```

   - Daphne (ASGI WebSocket) service — a devspoon-specific stack

     ```
     Stack: compose/web-service/nginx_daphne/
     Logrotate dropins: script/logrotate/daphne/{daphne,celery/daphne-celery,celerybeat/daphne-celerybeat}
     Image: shares devspoon-py-app:latest (same base as gunicorn / uvicorn, §0.5.4)
     Use case: WebSocket-only requirements such as Django Channels. The nginx side reuses the
     gunicorn stack's config/web-server/nginx/gunicorn/ folder, mounted as is.
     ```

     - **Run docker-compose.yml**

       ```
       Before first start, create .env and generate its secrets (repository root, §0.6.1):
           cp compose/web-service/nginx_daphne/.env-example compose/web-service/nginx_daphne/.env
           bash -c '. script/lib/django_secrets.sh && ensure_env_secrets compose/web-service/nginx_daphne/.env'
       Then replace FLOWER_ID. CELERY_BROKER_URL is composed from REDIS_PASSWORD (§0.5.3).

       Then move to the stack folder and run docker-compose.yml
       (--build rebuilds the images after an upgrade or a Dockerfile / uv.lock change, §0.6.4):
           cd compose/web-service/nginx_daphne
           docker compose up -d --build
       For celery / celery-beat / flower: "docker compose --profile celery up -d".
       ```

     Give the WebSocket path its own location in the domain conf and forward the Upgrade header.
     `nginx.conf` defines `map $http_upgrade $connection_upgrade`. Do **not** include `proxy_params`
     in this location — it sets `Connection ""`, which would send the same header twice:

     ```nginx
     location /ws/ {
         proxy_pass http://daphne-app:8000;
         proxy_http_version 1.1;
         proxy_set_header Host $host;
         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
         proxy_set_header X-Forwarded-Proto $scheme;
         proxy_set_header Upgrade $http_upgrade;
         proxy_set_header Connection $connection_upgrade;
     }
     ```

## Sample apps under `www/`

The sample apps under `www/` are references for verifying each stack immediately. Put your production code in the same place, in its own folder.

| Folder | Backend / stack | Notes |
|---|---|---|
| `www/django_sample/` | Usable from gunicorn, uwsgi, daphne and uvicorn. Django 6.0 (`django>=6.0,<6.1`), uv-managed (`pyproject.toml`, `uv.lock`) | `.python-version` = 3.14. On the host, `uv sync --extra celery` creates `.venv` automatically (settings' `django_celery_beat` belongs to the `celery` extra); in containers it installs straight into the system site-packages (§8) |
| `www/fastapi_sample/` | uvicorn only. Latest FastAPI, uv-managed | Added in §0.5.9 — verifies the uvicorn stack |
| `www/flask_sample/` | gunicorn or uwsgi only (WSGI). Flask, uv-managed | Added in §0.5.9 — verifies the WSGI stacks with a non-Django app |
| `www/php_sample/` | For php-fpm (7.3 or 8.4). A single `index.php` | Container path `/www/php_sample` (mounted as `../../../www:/www`) |
| `www/certbot/` | The standard ACME webroot location inside the container | Only `.gitkeep` is tracked to keep the empty directory. When issuing a certificate, the nginx conf aliases `/.well-known/acme-challenge/` to this path |

The usage flow is unchanged:
```
1) New app: create www/myapp/
2) Generate the domain conf: config/web-server/nginx/<stack>/nginx_http_conf.sh -w myapp -d ...
3) Set PROJECT_DIR=myapp in compose/web-service/nginx_<stack>/.env
   (docker-compose.yml only substitutes ${PROJECT_DIR}; the value itself lives in .env)
4) cd compose/web-service/nginx_<stack> && docker compose up -d --build
```

### Permanent sample `.conf` policy in `conf.d/` (instant verification)

Each stack's `config/web-server/nginx/<stack>/conf.d/` holds exactly **two kinds of permanent `.conf` file** (no `.example` pattern — single-extension policy):

| File | Role | Behaviour |
|---|---|---|
| `default.conf` | Sole owner of catch-all | `listen 80 default_server` + `listen 443 ssl default_server` + `server_name _` + `return 444` / `ssl_reject_handshake on`. Blocks unknown Host/SNI. **The only place default_server is defined** |
| `<sample>_<stack>_ng_http.conf` | Permanent sample for instant verification | `listen 80;` (no default_server) limited to `server_name localhost www.localhost;`. Loaded automatically when the nginx container starts, so `Host: localhost` returns HTTP 200 |

| Stack | Sample conf file |
|---|---|
| gunicorn | `django_sample_gunicorn_ng_http.conf` |
| uvicorn | `django_sample_uvicorn_ng_http.conf` |
| uwsgi | `django_sample_uwsgi_ng_http.conf` |
| php (shared by 7.3/8.4) | `sample_php_ng_http.conf` |

**Instant verification** (right after compose up):
```bash
curl -H "Host: localhost" http://localhost/    # → 200
```
No activation step (such as `cp .example .conf`) is needed. The sample's `listen 80;` and `default.conf`'s `listen 80 default_server;` share the same port without conflict, because the default_server keyword appears only in default.conf.

**Adding a per-domain production conf**: `nginx_http_conf.sh -w <webroot> -d <domain> -p 80 -a <appname> -s <serviceport> -n <name>` creates `conf.d/<name>_<stack>_ng_http.conf`. It has a different `server_name` from the sample, so the two coexist. To disable the sample in production, move it out of `conf.d/` or delete it (it is a permanent `.conf`, so it is tracked in git).

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

  1. Run nginx_http_conf.sh located in config/web-server/nginx/<service>. Create a conf file for each domain under config/web-server/nginx/<service>/conf.d/. Generated filenames always end with "_http" (e.g. <name>_gunicorn_ng_http.conf).

  2. Please edit compose/web-service/<service>/docker-compose directly and run it according to the service you want to use.

  3. This will run the default nginx using http.

  4. The "docker exec -it bash" command allows users to access docker internals.

  5. The script/letsencrypt.sh shell script file is linked per volume. This allows users to access script files directly from the nginx container.

  6. Run /script/letsencrypt.sh and enter the domain(s) and email. The ACME webroot is fixed to /www/certbot (every generated conf serves /.well-known/acme-challenge/ from it), so there is no webroot input.

  7. If you entered all keys correctly, use the exit command to exit the container.

  8. Now we need to create a conf file for https and delete the existing file.

  9. Run nginx_https_conf.sh located in config/web-server/nginx/<service>. Create a conf file for each domain under config/web-server/nginx/<service>/conf.d/.

  10. Users must remove the http conf file from config/web-server/nginx/<service>/conf.d/.

  11. Apply the new conf in the compose folder: `docker compose exec webserver nginx -t && docker compose exec webserver nginx -s reload` (or restart only nginx: `docker compose restart webserver`). Do not restart the whole stack for this — `docker compose restart` restarts every service at the same time, so nginx can come up while the app container is still stopping and exit once with `[emerg] host not found in upstream` (it restarts itself, see §5). To restart everything, use `docker compose stop` then `docker compose start`. Do not use the "docker compose down" command. Related configuration files may be deleted.

  12. The certbot renewal cron is built into the nginx image (`docker/nginx/Dockerfile` registers it in crontab at build time, and the cron daemon starts with the container). You do **not** need a host `crontab` entry or an external script. On renewal, `--deploy-hook "nginx -t && nginx -s reload"` makes nginx reload gracefully only when the certificate actually changed. For the full story, see "The single source of truth for the renewal cron" in §3.

  13. Check the registered cron inside the container: `docker compose exec webserver crontab -l` (certbot and ngxblocker renewals). The app container's `docker/<stack>/entrypoint-with-cron.sh` handles the logrotate cron only.

## Operator's Manual

> This section gathers the background knowledge, recommended settings and behaviours to watch out for when deploying and operating this project from an infrastructure / operations point of view. **Please read it before deploying to production.**

### 0. Reference environment and deployment policy

| Item | Value | Notes |
|---|---|---|
| Server spec | **8 cores / 8 GB RAM** | Every tuning number in this README is derived from this baseline. Recalculate the worker/pool figures for a different spec |
| Deployment | **manual stop/start (no zero-downtime)** | `docker compose stop` → update the code → `docker compose start`. Zero-downtime, blue-green and rolling deployments are not supported |
| Container base | `ubuntu:24.04` (LTS), `nginx:1.27-bookworm` | No `latest` tags — reproducible builds |
| Python | `3.14.0` (compiled from source, multi-stage builder + SHA256 verification) | Longer build, 5–10 % faster at runtime. SHA256 ARG default = `2299dae5...e9f3e9` (§0.5.4) |
| PHP 7.3 (legacy) | `romeoz/docker-phpfpm:7.3` | `docker/php-fpm/Dockerfile-7.3`. Multi-version paths (`/etc/php/7.3/fpm/...`). Upstream is unmaintained — prefer 8.4 for new deployments |
| PHP 8.4 (current) | `php:8.4-fpm-bookworm` (official) | `docker/php-fpm/Dockerfile-8.4`. Single-path layout (`/usr/local/etc/php{,-fpm.d}/...`). php.ini is patched for 8.x compatibility (`config/app-server/php-8.4/php_ini/php.ini`) |
| Redis | `redis:7.4-alpine` + `protected-mode yes` + `requirepass` | Alpine base keeps the image under 100 MB. Authentication is mandatory (§0.5.2) |
| Flower | `mher/flower:2.0.1` | The `master` tag is not reproducible and is forbidden. `FLOWER_BASIC_AUTH` is required |
| Image tags built here | `devspoon-py-app:latest`, `devspoon-uwsgi-app:latest`, `devspoon-nginx:latest`, `devspoon-php-app:{7.3,8.4}` | Declared with compose `image:` so stacks and services reuse them (§0.5.4). The `devspoon` prefix is `IMAGE_NAMESPACE` (default `devspoon`) — the verifiers and `verify-ngxblocker.sh` use `IMAGE_NAMESPACE=devspoon-it`, and run-ci's build step (`s2_build.sh`) uses `devspoon-test/*` so production tags are never overwritten (§0.6.4) |

#### Why is "manual stop/start" the default policy?
- This project primarily targets a single server (8c/8g). Without a load balancer or orchestrator (K8s), this is the simplest and safest deployment model.
- Giving up zero-downtime (graceful HUP reload) buys **lower memory use**:
  - gunicorn uses `preload_app=True` (`gunicorn.conf.py`, `uvicorn.conf.py` — loaded once in the master then forked, shared copy-on-write)
  - uwsgi uses `lazy-apps = true` (`uwsgi.ini` — each worker forks then loads the app; it gives up CoW savings to avoid shared state from before the fork)
- When zero-downtime does become a requirement, handle it in a dedicated PR / migration.

---

### 0.5. May 2026 security and structure hardening (recent sweep)

This section collects the policy changes applied together most recently. Some differ from the defaults described in earlier versions of this README, so read this section before the operations guide from §1 onwards.

#### 0.5.1 Externalised credentials — `.env` and `.env-example`

- The `compose/web-service/<stack>/.env` of each of the six stacks (daphne / gunicorn / uvicorn / uwsgi / php-7.3 / php-8.4) is **no longer tracked in git**. Only `.env-example` in the same folder is tracked; on a new environment, `cp .env-example .env` and generate the secrets with `ensure_env_secrets` (§0.6.1).
- The `.gitignore` pattern is `**/.env`; `.env-example` does not match it and stays tracked. The five previously tracked `.env` files were untracked with `git rm --cached` (the working tree copies were kept).
- compose's `${VAR:?error}` validation: if a credential key (`DJANGO_SECRET_KEY` for Python stacks, `REDIS_PASSWORD`, `FLOWER_ID`, `FLOWER_PWD`) is unset or empty, `docker compose up` fails fast — which rules out starting with an empty password.
- The logging keys (`LOG_DRIVER`, `LOG_OPT_MAXF`, `LOG_OPT_MAXS`) fall back with `${VAR:-default}`, so a missing `.env` entry has no effect.

#### 0.5.2 Stronger Redis authentication (`protected-mode yes` + `requirepass`)

- All six `redis.conf` files change `protected-mode no` to `yes`. Even inside the same docker network, no key is reachable without authentication.
- `redis.conf` does not support environment variable interpolation, so `requirepass` is injected from compose with `command: redis-server ... --requirepass ${REDIS_PASSWORD}`.
- A healthcheck was added to the redis container:
  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "redis-cli --no-auth-warning -a \"$$REDIS_PASSWORD\" ping | grep -q PONG"]
    interval: 10s
    timeout: 3s
    retries: 5
    start_period: 10s
  ```
- `depends_on: redis` on the app, celery, celery-beat and flower was strengthened to `condition: service_healthy`, holding dependent services back until redis answers authenticated pings — which removes the race condition.

#### 0.5.3 `CELERY_BROKER_URL` as a single source of truth (no drift)

- It used to be stored separately in `.env` as `CELERY_BROKER_URL=redis://:PASS@redis:6379/3`, so it had to be kept in sync with `REDIS_PASSWORD` — a drift risk.
- The `CELERY_BROKER_URL` key has now been **removed** from `.env`. The celery, celery-beat and flower `environment:` blocks in compose compose it directly as `redis://:${REDIS_PASSWORD:?...}@redis:6379/3`, so **updating the single REDIS_PASSWORD value keeps all four services in sync.**
- A side benefit: previously the celery and celery-beat containers received no `CELERY_BROKER_URL` environment variable, so a Django settings module reading `os.environ['CELERY_BROKER_URL']` fell back to `amqp://localhost` — a latent bug this change removes.

#### 0.5.4 Docker image build policy

- `docker/gunicorn/Dockerfile` and `docker/uwsgi/Dockerfile` were restructured as **multi-stage** builds:
  - **builder** stage: `ubuntu:24.04` + `build-essential` + `*-dev` libraries + Python 3.14 compiled from source + pip packages pre-installed (including natively built ones such as mysqlclient and psycopg2).
  - **runtime** stage: `ubuntu:24.04` + runtime libraries only + percona-xtrabackup-84 + pgbackrest + cron + logrotate. Dropping `build-essential` and `pkg-config` saves roughly 500 MB.
- **SHA256 verification** of the Python tarball was added:
  - `ARG PYTHON_SHA256=2299dae542d395ce3883aca00d3c910307cd68e0b2f7336098c8e7b7eee9f3e9` (official Python 3.14.0, confirmed 2026-05-18).
  - If `sha256sum -c` exits non-zero during the build, the RUN aborts — supply-chain tampering is detected.
  - When bumping the version, update the ARG after checking the [python.org Files table](https://www.python.org/downloads/release/python-3140/) or verifying the `.sigstore` bundle.
- Explicit `image:` tags in compose let stacks and services **reuse** images:
  - `devspoon-py-app:latest` — shared by the gunicorn, daphne and uvicorn stacks, and by celery / celery-beat inside each.
  - `devspoon-uwsgi-app:latest` — the uwsgi stack only.
  - `devspoon-nginx:latest`, `devspoon-php-app:7.3` / `devspoon-php-app:8.4`.
  - Effect: `docker compose build` used to rebuild the same context three or four times; now it builds once.

#### 0.5.5 Tighter uwsgi.ini privileges

- `username = root` was removed and `uid = www-data` / `gid = www-data` enabled. The master drops from root to www-data, mirroring the PHP-FPM pattern (least privilege).
- `chmod-socket = 666` is commented out — it is meaningless over TCP 8000. An inline comment explains to use 0660 if you switch to a unix socket later.
- `py-autoreload` in `sample_uwsgi.ini` changed from `1` to `0`, so a default unsuitable for production does not come back when the sample is copied.

#### 0.5.6 ulimits — defined but explicitly disabled

- `.env` defines `ULIMIT_NOFILE_SOFT=65535` and `ULIMIT_NOFILE_HARD=65535`.
- The ulimits block is present in the `webserver` service of all six compose files but **commented out**, because the host docker daemon's default LimitNOFILE (typically 1048576) already covers 65535. Uncomment it only where the host OS caps nofile below 65535 (RHEL, podman, some K8s nodes).

#### 0.5.7 redis-stats removed

- `insready/redis-stat:latest` (unmaintained since 2017, no security patches) was deleted from all six compose files, along with its host `63790/tcp` exposure.
- If you need a replacement, consider RedisInsight or `oliver006/redis_exporter` (for Prometheus).

#### 0.5.8 Unified tzdata pattern in the PHP-FPM Dockerfiles

- `dpkg-reconfigure tzdata` was removed from `Dockerfile-7.3` and `Dockerfile-8.4`. They now use the same pattern as the gunicorn, uwsgi and nginx Dockerfiles: `ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone`.
- Six duplicated install layers in `Dockerfile-7.3` were compressed into a single RUN.

---

### 0.6. September 2026 Django 6 upgrade — required operator changes

#### 0.6.1 Generating `.env` secrets (first setup · upgrade)

The secrets in `.env-example` are **empty** (`DJANGO_SECRET_KEY`, `REDIS_PASSWORD`, `FLOWER_PWD` for Python stacks; `REDIS_PASSWORD` for php). Compose requires them with `${VAR:?}`, so startup is refused while they are blank. Run this once per stack, from the repository root:

```bash
cp compose/web-service/nginx_gunicorn/.env-example compose/web-service/nginx_gunicorn/.env
bash -c '. script/lib/django_secrets.sh && ensure_env_secrets compose/web-service/nginx_gunicorn/.env'
```

- Only secret keys that are empty or still hold the old `CHANGE_ME_*` placeholder are filled with `openssl rand -hex` values (`DJANGO_SECRET_KEY` 100 hex, everything else 64 hex). Keys that already have a value are left alone.
- The helper writes to a temporary file in the same folder and swaps it in; if it generated anything, it tightens the permissions to 600 (stricter permissions are kept). If openssl is missing or fails it ends with `FAIL` and `.env` is untouched.
- `FLOWER_ID` is not a secret and is not filled — replace `CHANGE_ME_FLOWER_USER` yourself.
- `www/django_sample/secrets.json` is only needed when you run `manage.py` directly on the host: `bash -c '. script/lib/django_secrets.sh && ensure_django_secrets'` (created only when missing, mode 600). Install the dependencies with `cd www/django_sample && uv sync --extra celery` — `django_celery_beat` in `INSTALLED_APPS` exists only in the `celery` extra, so without `--extra celery` you get a `ModuleNotFoundError`. Containers use the `DJANGO_SECRET_KEY` environment variable.

> **Upgrade note — keeping an `.env` from an older version**: an old `.env` may have no `DJANGO_SECRET_KEY` line at all, or may still hold `CHANGE_ME_*` values. Running the helper once on that same `.env` appends the missing keys — those required with `:?` by `docker-compose*.yml` in the same folder and by any fragment they pull in with `include:`, whose names contain SECRET, PASSWORD or PWD — replaces `CHANGE_ME_*`, preserves existing values and sets the file mode to 600. A quoted empty value such as `KEY=""` is not filled; change it to `KEY=` first.

#### 0.6.2 SQLite data location — the named volume `/data`

For the Python stacks (gunicorn, uvicorn, uwsgi, daphne), SQLite lives at **`/data/<PROJECT_DIR>.sqlite3`** in the compose named volume `app-data` (the `SQLITE_PATH` environment variable), not at `www/<PROJECT_DIR>/db.sqlite3` on the host. The container chowns only that volume and the log directories to www-data; the host source tree (`/www`) is never chowned. Running `manage.py` on the host without `SQLITE_PATH` still uses `www/<PROJECT_DIR>/db.sqlite3`.

**Migrating an existing database** (to keep using the host `db.sqlite3` — gunicorn stack shown; start the celery profile after the migration):

```bash
cd compose/web-service/nginx_gunicorn
docker compose up -d        # creates the app-data volume (migrated as an empty DB)
docker compose cp ../../../www/django_sample/db.sqlite3 gunicorn-app:/data/django_sample.sqlite3
docker compose exec gunicorn-app chown www-data:www-data /data/django_sample.sqlite3
docker compose restart gunicorn-app   # the startup command runs again and applies pending migrations to the copied DB (app only — a full restart hits the race in §5)
```

> ⚠️ **`docker compose down -v` deletes the `app-data` volume, and with it the SQLite database.** Use `docker compose stop` when you only want to bring the containers down (`down` is discouraged by the §6 deployment policy, `-v` especially). Backup: `docker compose cp gunicorn-app:/data/django_sample.sqlite3 ./backup.sqlite3`.

#### 0.6.3 Startup order — the app initialises the DB, then celery and beat

- Only the app service of each stack initialises the database once before the server starts: `python manage.py migrate --noinput` when `manage.py` exists, otherwise (flask/fastapi) the project's `prestart.sh`. Put table creation for a new non-Django project in `www/<PROJECT_DIR>/prestart.sh`.
- `celery` and `celery-beat` are bound with `depends_on: <app>: condition: service_healthy`, so they start after the app is healthy — no two containers race to migrate. `flower` starts after `celery-beat`.

#### 0.6.4 Image names · build

- Image names follow `${IMAGE_NAMESPACE:-devspoon}-nginx:latest`. With the default you get the familiar `devspoon-*` tags; the verifiers and `verify-ngxblocker.sh` use `IMAGE_NAMESPACE=devspoon-it`, and run-ci's build step (`s2_build.sh`) uses `devspoon-test/*`, so production tags are never overwritten.
- The pre-installed packages in the app images (`py-app`, `uwsgi-app`) are derived from `www/django_sample/uv.lock`. Compose passes it automatically via `build.additional_contexts: lock: ../../../www/django_sample`, which needs **Docker Compose ≥ 2.17** (`docker compose version`).
- If your Compose is older than 2.17, or you call `docker build` directly, pass the extra build context explicitly (from the repository root, with BuildKit):

  ```bash
  docker build --build-context lock=www/django_sample -t devspoon-py-app:latest docker/gunicorn/
  docker build --build-context lock=www/django_sample -t devspoon-uwsgi-app:latest docker/uwsgi/
  ```

  Leaving it out makes the build fail with `"/pyproject.toml": not found`.

#### 0.6.5 nginx configuration

- **Rate limiting — bots only**: the shared `nginx.conf` http block defines `limit_conn_zone $bot_iplimit zone=addr:50m;` and `limit_req_zone $bot_iplimit zone=flood:50m rate=90r/s;`. `$bot_iplimit` only carries an IP for requests `globalblacklist.conf` judged to be a bot, so the limits in `bots.d/ddos.conf` apply to bot traffic and leave normal users alone. The upstream `botblocker-nginx-settings.conf` is not included (its hash directives were moved into nginx.conf).
- **`proxy.d`**: nginx.conf reads `include /etc/nginx/proxy.d/*/*.conf;` before conf.d. The compose files here do not mount `proxy.d`, so it is a no-op; sibling repositories use it when they mount extra reverse-proxy services at `/etc/nginx/proxy.d/<svc>/`.
- **WebSocket**: nginx.conf defines `map $http_upgrade $connection_upgrade` (see the Daphne example).
- **real_ip**: all four nginx.conf files carry commented example blocks for CloudFlare, AWS ALB and an in-house LB; they are disabled by default (OPS-GUIDE-006 §2).
- **HTTPS template** (`sample_nginx_https.conf`): HSTS is `max-age=63072000; includeSubDomains` — `preload` is deliberately absent (add it only after you decide to register at hstspreload.org, OPS-GUIDE-002 §2). OCSP stapling is off by default (Let's Encrypt certificates carry no OCSP responder URL). Session cache is `shared:SSL:10m`.

#### 0.6.6 Django settings · Flower

- `DJANGO_DEBUG` (default `0`) and `DJANGO_ALLOWED_HOSTS` (gunicorn default `localhost,www.localhost,127.0.0.1`) are controlled through `.env` and passed to the app, celery and beat. Add your domain to `DJANGO_ALLOWED_HOSTS` when you connect one, and use `DJANGO_DEBUG=1` only for local development.
- Flower binds to **`127.0.0.1:5555` only**. Reach it over an SSH tunnel: `ssh -L 5555:127.0.0.1:5555 <host>`, then open `http://127.0.0.1:5555` locally.

#### 0.6.7 Test harness variables

| Variable | Default | Purpose |
|---|---|---|
| `IMAGE_NAMESPACE` | `devspoon` (the verifiers and `verify-ngxblocker.sh` use `devspoon-it`; run-ci's `s2_build.sh` uses `devspoon-test/*`) | Image name prefix |
| `S5_DOMAIN` | `s5-https.test` | The test HTTPS domain used by `s5_https.sh` |
| `S5_WAIT` | `20` | Maximum seconds `s5_https.sh` waits for an HTTPS response after a reload |
| `STABLE_WINDOW` | `15` | The stabilisation window (seconds) over which a verifier observes containers staying running with an unchanged RestartCount |

`bash script/ci/run-ci.sh` runs ten steps in order: preflight → prereq and log directories → nginx conf generators → compose validation → image builds → static regression (s6) → healthcheck → stack matrix → sample projects → script logs.

---

### 1. How the app-server worker / pool figures were derived

Memory available on an 8-core / 8 GB box: `8 GB - (OS + nginx + redis + headroom ≈ 2 GB) ≈ 6 GB`.

| Service | Key figures | Rationale |
|---|---|---|
| **gunicorn (Django sync)** | `workers=4, threads=2` (`gunicorn.conf.py`) | At ~250 MB per worker, 4 × ≈ 1 GB. `threads=2` absorbs DB I/O waits, giving 8 concurrent slots. `timeout=60`, `max_requests=1000`, `preload_app=True` |
| **uvicorn (FastAPI ASGI)** | `workers=8` (UvicornWorker, `uvicorn.conf.py` — the one compose uses) | Async workers handle many requests on a single event loop; one worker per core. At ~600 MB per worker, 8 × ≈ 4.8 GB. The alternative `gunicorn_uvicorn.conf.py` uses `workers=4` |
| **uwsgi (Django)** | `processes=4` (no threads option, `enable-threads=true`) | Sync workers. `harakiri=60`, `lazy-apps=true`. `reload-on-rss` is unset — add it if you want automatic restarts on memory growth |
| **daphne (ASGI WS)** | single process | daphne has no multi-process mode. A single instance handles thousands of concurrent websockets; beyond that, use an nginx upstream with several containers |
| **celery worker** | `--concurrency=8 --max-tasks-per-child=2000` | Prefork pool matched to the core count. Workers restart every 2000 tasks as a defence against memory leaks |
| **php-fpm** (shared by 7.3/8.4) | `pm = dynamic`, `pm.max_children=50, start=5, min_spare=5, max_spare=35` | At ~80 MB per worker, 50 × ≈ 4 GB. `request_terminate_timeout=60s` guards against hangs. Both versions use the same pool policy — the files are `config/app-server/php-{7.3,8.4}/pool.d/www.conf`, and the only difference is the 8.x compatibility patch in php.ini |

> **Caution — the side effects of `preload_app=True`**:
> - If you open a DB connection at module import time, the forked workers share one socket and can collide.
> - Fix: create DB connections lazily on the first request, or recreate them explicitly in a `post_fork` hook.
> - The Django ORM handles this for you; SQLAlchemy with raw psycopg2 and similar setups do not.

---

### 2. Log layout (one identifiable tree)

**Every log goes into a single host-side `./log/` tree**, mounted inside the containers at `/log/`.

```
log/
├── nginx/              # nginx access/error + certbot renewal logs
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
└── supervisor/         # (reserved slot)
```

- **Logs survive a dead container** (host volume mount).
- Every folder is tracked with `.gitkeep`, directly or through a subfolder.
- When you add a new service, always add `log/<service>/` and its `.gitkeep`.

#### Logrotate
- The host's `script/logrotate/<service>/<service>` is mounted into the container at `/etc/logrotate.d/<service>`.
- Policy: **`copytruncate`** — rotation without restarting the service (the trade-off is that a tiny amount of log can be lost at the moment of rotation).
- Retention: 30 days by default (php-fpm access 7 days, slow log 90 days — diagnosis first).
- Check that it applies:
  ```bash
  docker exec -it <container> logrotate -d /etc/logrotate.d/<service>
  ```

---

### 3. SSL / HTTPS / certbot auto-renewal

#### The single source of truth for the renewal cron
- **`docker/nginx/Dockerfile` is the only source of truth.**
- `script/letsencrypt.sh` is for the initial issuance only — it registers no cron line (deliberately removed).
- The registered cron:
  ```cron
  0 5 * * 1 certbot renew --quiet --deploy-hook "nginx -t && nginx -s reload" >> /log/nginx/crontab_YYYYMMDD.log 2>&1
  ```

#### Inside a container, reload nginx only with `nginx -s reload`
- `service nginx restart` and `systemctl reload nginx` are **forbidden** — in a container where PID 1 is nginx they either do nothing or kill the whole container.
- `nginx -s reload` sends `SIGHUP` to the master, which spawns new workers and shuts the old ones down gracefully.
- Always `nginx -t &&` first, so a **broken config never reaches production** on reload.

#### Checking the cron
```bash
docker exec -it nginx-<service>-webserver bash -c "crontab -l"
docker exec -it nginx-<service>-webserver bash -c "ps aux | grep cron"
# watch the next run
tail -f log/nginx/crontab_*.log
```

#### First issuance (summary)
1. Start the container with an HTTP-only nginx conf
2. `docker exec -it <nginx-container> bash`
3. Run `/script/letsencrypt.sh` (enter webroot / domain / e-mail)
4. `exit` once it is issued
5. Swap in the HTTPS conf → `docker compose exec webserver nginx -t && docker compose exec webserver nginx -s reload`

#### Persisting dhparam — baked into the image, with a host backup/restore hook

Background: dhparam (`ssl_dhparam`) is neither a secret nor domain-specific, so **one shared copy for the whole stack** is enough. Older versions mounted the host's `ssl/certs/` over `/etc/ssl/certs`, which shadowed the system CA bundle (`/etc/ssl/certs/ca-certificates.crt`) and broke certbot issuance. This version removes that anti-pattern and replaces it with **baking it once at build time plus a host backup/restore hook.**

| Location | Role | Who creates it |
|---|---|---|
| `docker/nginx/Dockerfile` section 8 | `openssl dhparam -out /etc/nginx/dhparam.pem 2048` — bakes dhparam into the image | Build step |
| `docker/nginx/Dockerfile` section 9 / `/docker-entrypoint.d/20-dhparam.sh` | Restores from the host backup if there is one, otherwise creates it | Hook just before nginx starts (the official image's entrypoint.d) |
| `compose/web-service/<stack>/ssl/dhparam/` (host) | Restore source / backup target, mounted at `/etc/nginx/dhparam-backup/` | The operator, or the automatic backup hook |
| `/etc/nginx/dhparam.pem` (container) | The file nginx actually reads — the path `ssl_dhparam` points at in `sample_nginx_https.conf` | The hook, restoring or using the baked copy |

How it plays out:

1. **First start** (host `ssl/dhparam/` empty) → the hook **copies** the image's dhparam.pem into the host backup directory. The same key is now persisted on the host.
2. **Restart after `docker compose down`** → a host backup exists, so the hook **restores it over the image's copy**. nginx uses exactly the dhparam key it used on the first start.
3. **Image rebuild** (for example bumping the nginx base version, which bakes a fresh dhparam) → the hook prefers the host backup, keeping the production key identical. To adopt the new dhparam deliberately, delete the host's `ssl/dhparam/dhparam.pem` and restart.

#### Startup-order hook — waiting for upstream names to resolve (`30-wait-upstreams.sh`)

When nginx starts it resolves the app container names written in `proxy_pass` / `uwsgi_pass` / `fastcgi_pass`. If the webserver comes up before the app — after a host reboot, or on `docker compose start` — the name does not exist and nginx exits with `[emerg] host not found in upstream` (`restart: always` brings it back, but it dies once).

| Location | Role |
|---|---|
| `docker/nginx/Dockerfile` section 10 / `/docker-entrypoint.d/30-wait-upstreams.sh` | Waits until the upstream names in conf.d (and `proxy.d` in the startup-series repositories) resolve, then starts nginx |
| `NGINX_UPSTREAM_WAIT` (webserver `environment`) | Maximum wait in seconds. Default 30; `0` disables the hook |

- Excluded from the wait: unix sockets, `$variables`, IP literals, `localhost`, and names defined by an `upstream` block within the conf.
- If a name still does not resolve when the wait expires, the hook logs a warning and starts anyway (a genuine misconfiguration still surfaces as nginx's `[emerg]`).
- A whole-project `docker compose restart` restarts services simultaneously, so the app can go down **after** the hook has checked — apply config changes with `nginx -s reload` and restart everything with `stop` → `start` (§5).
- Regression: `script/test_run/s6_regression.sh` 6.38.

Verification:

```bash
# is dhparam baked into the freshly built image?
docker run --rm devspoon-nginx:latest cat /etc/nginx/dhparam.pem | head -1
# → "-----BEGIN DH PARAMETERS-----"

# check the host backup after starting the container
ls -la compose/web-service/nginx_gunicorn/ssl/dhparam/
# → dhparam.pem should exist

# confirm the same key is in use (compare digests)
docker exec -it nginx-gunicorn-webserver sha256sum /etc/nginx/dhparam.pem
sha256sum compose/web-service/nginx_gunicorn/ssl/dhparam/dhparam.pem
# → the two values should match
```

For a fuller verification script, use `script/test_run/ssl_diag.sh` (see §10.3).

> **Note for WSL**: the host dhparam backup (`ssl/dhparam/dhparam.pem`) can be created owned by container root, leaving the host user unable to change it. Modify or delete it from inside the container, or with `sudo` on the host (see §11.2 for the procedure).

---

### 3.5. Blocking malicious bots / DDoS — nginx-ultimate-bad-bot-blocker

The old static `bad_bot.conf` (500+ patterns maintained by hand) is gone, replaced by [nginx-ultimate-bad-bot-blocker](https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker), which refreshes from upstream every six hours.

#### At build time (`docker/nginx/Dockerfile`)
1. Downloads `install-ngxblocker`, `setup-ngxblocker` and `update-ngxblocker`
2. Runs `install-ngxblocker -x`, baking the initial data into the container:
   - `/etc/nginx/conf.d/globalblacklist.conf` (the map definitions for every bot / scanner / scraper — provides `$bad_bot`, `$bad_referer`, `$validate_referer` and friends)
   - `/etc/nginx/bots.d/blockbots.conf` (server-level blocking logic)
   - `/etc/nginx/bots.d/ddos.conf` (DDoS pattern blocking)
   - `/etc/nginx/bots.d/{blacklist,whitelist}-*.conf` (empty files for operator customisation)

#### At runtime
- Cron inside the container runs `update-ngxblocker` **every six hours**, refreshing only globalblacklist.conf, then `nginx -t && nginx -s reload` (graceful reload)
- The registered cron line:
  ```cron
  0 */6 * * * /usr/local/sbin/update-ngxblocker >> /log/nginx/ngxblocker_YYYYMM.log 2>&1 && nginx -t && nginx -s reload
  ```
- Same source of truth as the certbot renewal cron (the Dockerfile) — no extra sudo work in production

#### The integration pattern in sample_nginx*.conf
The old `if ($bad_bot) { return 403; }` in each domain server block is replaced by this **two-line include**.
Of ngxblocker's nine `bots.d/` files, only these two belong in the server context:

```nginx
include /etc/nginx/bots.d/blockbots.conf;   # server-level `if ($bad_bot)` check + return 444
include /etc/nginx/bots.d/ddos.conf;        # server-level limit_conn / limit_req (bots only)
```

> ⚠️ **Do not include `bots.d/{whitelist,blacklist}-*.conf`, `bots.d/bad-referrer-words.conf` or
> `bots.d/custom-bad-referrers.conf` directly in a server block.**
> Those files hold `map`/`geo` data entries (`1.2.3.4 1;`, `~*pattern 1;`) and are only valid inside a
> map/geo block in the http context. Leave them in a server block and the moment an operator adds a
> single entry, `nginx -t` fails → the reload is refused → production goes down.
> globalblacklist.conf includes those seven files automatically in the http context, so an operator
> only has to add entries to the files themselves — no server block changes.

#### Files the operator edits (per-domain white/blacklists)
The customisation layer upstream never touches — `update-ngxblocker` does not overwrite these.
**Just add entries to the file; globalblacklist.conf picks them up in the http context.**
Do not modify the server block:

| File | Purpose | Example format |
|---|---|---|
| `/etc/nginx/bots.d/whitelist-ips.conf` | IPs/CIDRs never to block | `203.0.113.0/24 0;` |
| `/etc/nginx/bots.d/whitelist-domains.conf` | Referer domains never to block | `~*example\.com 0;` |
| `/etc/nginx/bots.d/blacklist-ips.conf` | Extra IPs/CIDRs to block | `198.51.100.5 1;` |
| `/etc/nginx/bots.d/blacklist-user-agents.conf` | Extra User-Agents to block | `~*MyEvilBot 1;` |
| `/etc/nginx/bots.d/custom-bad-referrers.conf` | Extra referrer keywords to block | `~*spam\-keyword 1;` |

> ⚠️ **`bots.d/blacklist-domains.conf` is not included by globalblacklist.conf, so entries added there
> have no effect.** The Dockerfile only touches it into existence as an empty file.
> Block extra referer domains through `custom-bad-referrers.conf`, or through
> `blacklist-user-agents.conf` if you can match on the UA.

After editing: `docker exec -it nginx-<svc>-webserver bash -c "nginx -t && nginx -s reload"`.

#### Verifying it works
```bash
# 1) confirm a known bot User-Agent is blocked
curl -A "MJ12bot" -o /dev/null -s -w "%{http_code}\n" http://localhost/
# → 444 (or 403) is correct

# 2) a normal browser UA passes
curl -A "Mozilla/5.0" -o /dev/null -s -w "%{http_code}\n" http://localhost/
# → 200/3xx/4xx (not 502/503)

# 3) check the update log
docker exec -it nginx-<svc>-webserver tail -20 /log/nginx/ngxblocker_$(date +%Y%m).log
```

#### Rollback (in an emergency)
```bash
# 1) temporarily disable globalblacklist.conf inside the container
#    (ngxblocker is installed with -c /etc/nginx, so it sits directly under /etc/nginx/, not conf.d.
#     Simply moving the file makes the include line in nginx.conf a file-not-found and nginx -t fails —
#     commenting the include line out is safer. nginx.conf is bind-mounted from the host, so a sed
#     inside the container updates the host file too and the change survives the next start.)
docker exec -it nginx-<svc>-webserver sed -i \
    's|^\(\s*\)include /etc/nginx/globalblacklist.conf|\1# include /etc/nginx/globalblacklist.conf|' \
    /etc/nginx/nginx.conf
docker exec -it nginx-<svc>-webserver bash -c "nginx -t && nginx -s reload"
# to revert: restore the include line in nginx.conf from git → reload

# 2) or restore the static bad_bot.conf from before the ngxblocker migration, from git
#    git log --diff-filter=D -- config/web-server/nginx/gunicorn/conf.d/bad_bot.conf  # find the deleting commit
#    git show <DELETE_COMMIT>^:config/web-server/nginx/gunicorn/conf.d/bad_bot.conf > config/web-server/nginx/gunicorn/conf.d/bad_bot.conf
#    then git revert the sample_nginx*.conf changes, remount into the container's conf.d and reload
```

---

### 4. Recommended OS-level tuning

For `backlog=2048` (gunicorn / uwsgi / php-fpm) to have any real effect, raise the kernel parameters too.

```bash
# /etc/sysctl.d/99-devspoon-web.conf
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.ip_local_port_range = 10000 65535
vm.overcommit_memory = 1            # recommended for Redis
fs.file-max = 200000

# apply
sudo sysctl --system
```

- ulimit: set `nofile=65536` through the docker daemon's `default-ulimits`.
- The 8 GB RAM ceiling: keep 2–4 GB of swap as OOM protection during memory spikes.

---

### 5. Issues you will run into in production

| Symptom | Likely cause | What to do |
|---|---|---|
| Container OOM kill | Total worker memory > 6 GB | Watch RSS with `docker stats`, then lower workers or max_requests |
| Workers restarting unexpectedly | `max_requests` reached, or `harakiri`/`timeout` | Look for "Worker timeout" in the error log. Move long-running work into celery |
| Intermittent 502 Bad Gateway | Upstream shutdown timing vs nginx keepalive | Check that gunicorn's `keepalive` is shorter than nginx's `keepalive_timeout` |
| celery memory growth | Memory leak in the prefork workers | Confirm `--max-tasks-per-child=2000` is in effect. Library memory fragmentation (numpy/pandas especially) is a possibility |
| logrotate not running | Wrong host path, or cron not installed | Check the folder name `script/logrotate` (note the s) and that the container's cron daemon is running |
| certbot renewal failing | webroot permissions, DNS change, port 80 blocked | Check `/log/nginx/crontab_*.log`. Manual dry run: `certbot renew --dry-run` |
| `[emerg] host not found in upstream "<app>"` in the webserver log (webserver exits once, then restarts itself) | nginx resolves the app container names in the conf when it starts. If nginx comes up before the app (host reboot, `docker compose start`), or a whole-project `docker compose restart` restarts everything at once and nginx comes up as the app goes down, the name does not exist | On the startup side, the nginx image's `/docker-entrypoint.d/30-wait-upstreams.sh` waits up to `NGINX_UPSTREAM_WAIT` seconds (default 30, adjustable through the webserver `environment`, `0` disables it) for the names to resolve — this needs an image rebuild (`--build`). It cannot fully cover a whole-project `restart`, where the app can go down after the hook has checked, so apply config changes with `nginx -s reload` or `docker compose restart webserver`, and restart everything with `stop` → `start`. If the message keeps appearing, check for a mismatch between the app name in the conf and the compose `container_name`/alias |
| DB errors after `preload_app=True` | DB connection shared across forks | Call `connections.close_all()` (Django) or recreate the engine in a `post_fork` hook |

---

### 6. Deployment procedure (manual stop/start)

```bash
# 1. pull the new code
git pull origin main

# 2. build if a Dockerfile changed (skip otherwise)
cd compose/web-service/nginx_<service>
docker compose build --no-cache <service>-app   # only the service that needs it

# 3. stop, including profile services — the celery profile for Python stacks and the redis profile
#    for PHP stacks. A stop without the profile leaves them running. A profile name that does not
#    exist in the stack is ignored, so the same command works for both stacks
docker compose --profile celery --profile redis stop

# 4. start
docker compose --profile celery --profile redis up -d

# 5. health check
docker compose ps
docker compose logs --tail=100 -f <service>-app

# 6. external health check
curl -fsS https://<domain>/health || echo "FAIL"
```

> **Do not use `docker compose down`** — it removes some network and volume metadata with it, which can cost you a rebuild of the SSL and redis data. In particular, **`docker compose down -v` deletes the named volume `app-data` (the SQLite database, §0.6.2)**.

---

### 7. Security / operations checklist

- [ ] Never commit the secrets in `.env` (`DJANGO_SECRET_KEY`, `REDIS_PASSWORD`, `FLOWER_ID`, `FLOWER_PWD`). Check the `**/.env` pattern in `.gitignore` (§0.5.1). Generate secrets with `ensure_env_secrets` (§0.6.1). `CELERY_BROKER_URL` is not in .env — compose composes it from REDIS_PASSWORD (§0.5.3).
- [ ] `flower` binds to `127.0.0.1:5555` only — reach it through an SSH tunnel (`ssh -L 5555:127.0.0.1:5555 <host>`) and do not change it to an external bind (`FLOWER_BASIC_AUTH` is enforced, but it is a single line of defence, §0.6.6). `redis-stats` was removed, so adopt RedisInsight or redis_exporter if you need monitoring (§0.5.7).
- [ ] Keep redis on the internal container network only (no host port exposed is the default — keep it that way). `protected-mode yes` + `requirepass` are enforced, so even containers on the same network must authenticate (§0.5.2).
- [ ] When building the Python base image, re-confirm once a quarter that `docker build --build-arg PYTHON_SHA256=<official>` or the ARG default in `docker/gunicorn/Dockerfile` matches the official python.org hash (§0.5.4).
- [ ] Review the cron time in `docker/nginx/Dockerfile` (Mondays 05:00) against your own traffic pattern and pick a quiet window.
- [ ] Monitor log disk usage — alert when `df -h log/` reaches 80 %.
- [ ] In `ufw` or the cloud firewall, expose only 80/tcp and 443/tcp and block everything else (flower's 5555 binds to host localhost, so it needs no firewall rule).
- [ ] Keep OS time in sync (`chrony` or `systemd-timesyncd`) — certbot, cron and log timestamps depend on it.

---

### 8. Python dependencies / uv policy — "no virtualenv inside the container"

This project manages the Python dependencies of `www/django_sample` with **uv**, but deliberately does **not create a separate virtualenv (`.venv`) inside the containers.** The container is already the isolation boundary, so a venv is a redundant extra layer that only complicates troubleshooting.

#### How it works

- `docker/gunicorn/Dockerfile` and `docker/uwsgi/Dockerfile` hard-code these ENVs:
  ```
  UV_PROJECT_ENVIRONMENT=/usr/local
  UV_LINK_MODE=copy
  UV_COMPILE_BYTECODE=1
  UV_NO_CACHE=1
  ```
- Because of that, `uv sync` inside the container creates no `.venv` and installs straight into **`/usr/local/lib/python3.14/site-packages` (the system Python)**.
- The compose `command:` calls the system binaries (`gunicorn`, `daphne`, `uwsgi`, `celery`) directly rather than going through `uv run`.
- The `--inexact` flag protects the packages the Dockerfile pre-installed (fastapi, sqlalchemy, wheel and so on) from being removed.

#### What the operator gains

| Item | With a venv | This project (system install) |
|---|---|---|
| Debugging an import | `uv run python -c "import django"` | `python -c "import django"` |
| Listing packages | `uv pip list --python .venv/bin/python` | `pip list` |
| Host directory | `www/<project>/.venv/` appears on the host | The host keeps only source, staying clean |
| Cross-volume hardlinks | Frequent conflicts → need `UV_LINK_MODE=copy` to work around | Same layer, so no effect |
| Two venvs in one container | Possible, and confusing | One system site-packages → no ambiguity |

#### On a development machine it is the opposite

`UV_PROJECT_ENVIRONMENT` does not exist on the host, so `cd www/django_sample && uv sync --extra celery` creates a `.venv` automatically (`--extra celery` is needed to run `manage.py` on the host, because of `django_celery_beat` in settings). Host and container share the same `pyproject.toml` and differ only in where packages land.

#### Adding or updating a dependency

```bash
# on the host (development machine):
cd www/django_sample
uv add requests                      # add a runtime dep → updates pyproject.toml + uv.lock
uv add --optional celery django-celery-results  # add to an extra → [project.optional-dependencies].celery
uv add --dev pytest-mock             # add a dev dep
uv lock                              # regenerate the lock only (if needed)

# commit the change:
git add pyproject.toml uv.lock
git commit -m "deps: add requests"

# restart the containers → uv sync runs at startup and applies it to the system Python
# (the app image's pre-installed set is also derived from uv.lock, hence --build, §0.6.4):
cd ../../compose/web-service/nginx_<service>
docker compose --profile celery stop && docker compose up -d --build
docker compose --profile celery up -d   # if you use celery (a stop without the profile leaves celery running)
```

#### Troubleshooting examples

```bash
# 1) check what is installed inside the container — no venv activation needed
docker exec -it gunicorn-app pip list | grep -i django

# 2) drop straight into a Django ORM shell
docker exec -it gunicorn-app python manage.py shell

# 3) confirm where uv sync actually installs
docker exec -it gunicorn-app uv pip list --system
docker exec -it gunicorn-app python -c "import django; print(django.__file__)"
# → /usr/local/lib/python3.14/site-packages/django/__init__.py
```

#### Caution — keep the extras-race rule

Every Python container in the same compose stack (app + celery + celerybeat) must `uv sync` with **exactly the same set of extras**. They share the system site-packages, so a container syncing with different extras can remove another container's packages. `--inexact` is a first safety net, but keep the extras combination consistent.

---

### 9. Impact matrix for changes

| Change | Rebuild needed? | Container restart needed? |
|---|---|---|
| `docker/<service>/Dockerfile` | ✅ `docker compose build` | ✅ |
| `config/app-server/*/...` (conf.py, ini) | ❌ (volume-mounted) | ✅ (reload workers) |
| `config/web-server/nginx/...` (managed separately) | ❌ | `nginx -s reload` on the nginx container only |
| `compose/.../docker-compose.yml` | Depends on the change | ✅ |
| `script/logrotate/*` | ❌ | ❌ (applies from the next cron tick) |
| `script/letsencrypt.sh` | ❌ | ❌ |
| `script/test/*` | ❌ | ❌ (host-side manual verification assets, unrelated to production) |

---

### 10. Test / verification infrastructure (`script/test/`)

The scripts in `script/test/` are **unrelated to the production images and stacks**. Nothing in the Dockerfiles or compose files references them, and they never go inside a container. They are assets a developer runs directly on the host (assumed to be WSL2 Ubuntu + Docker) to check consistency and catch regressions. **Deleting the folder has no effect on the running services** — it is purely a regression-testing convenience.

#### Contents (two files)

| File | Kind | Duration | Changes containers? |
|---|---|---|---|
| `preflight.sh` | Environment pre-check (read-only) | ~30 s | None |
| `verify-ngxblocker.sh` | End-to-end ngxblocker verification | 1–3 min | Starts the gunicorn stack's webserver and redis under a dedicated compose project (`-p devspoon-ngxb-test`), then `down -v` on that project only when it finishes (stop the production stack first), plus adding and removing a temporary conf (the script cleans up after itself) |

---

#### 10.1 `preflight.sh` — pre-check when setting up a new environment

A **read-only** script that confirms in about 30 seconds that the host meets the requirements, before you start a test or production setup. It creates and changes nothing, and starts no containers.

**Usage**

```bash
cd /path/to/devspoon-web     # repository root
bash script/test/preflight.sh
```

Exit codes: `0` = PREFLIGHT PASS (safe to start testing / deploying), `1` = PREFLIGHT FAIL (something is missing — fix the `[MISS]` lines on screen and run it again).

**When to run it**

1. **Right after setting up a new dev environment** (WSL2 / cloud VM) — confirm no required tool is missing.
2. **Right after a major OS or Docker update** — catch regressions such as the `docker compose v2` migration.
3. **In the first 30 minutes of onboarding a new team member** — it cuts down the "why doesn't this work?" round trips.
4. **As the first step of a CI workflow** — it makes the dependencies visible (the script doubles as environment documentation).

**What it checks** (four categories)

| Category | Example items | On failure |
|---|---|---|
| `[1] Required tools` | `docker` (>=24), `docker compose` (v2), `jq`, `curl`, `openssl`, `wrk` (optional) | `[MISS]` — install that tool |
| `[2] Repository files` | A `.env` for each of the stacks (gunicorn / uvicorn / daphne / uwsgi / **nginx_php-7.3 / nginx_php-8.4**), four kinds of Dockerfile (**both php-fpm 7.3 and 8.4**), the entrypoints, `pyproject.toml`, `script/letsencrypt.sh` | `[MISS]` — repository integrity is broken. Re-clone or check git status |
| `[3] Design invariants` | The folder name `script/logrotate` (not the typo 'loglotate'), `log/.gitkeep × 11`, whether `pyproject.toml` is PEP 621, `UV_PROJECT_ENVIRONMENT=/usr/local`, FROM base consistency, absence of a `service nginx restart` regression, `uwsgi.ini py-autoreload=0` and so on | `[MISS]` — a deliberate design decision was broken. See §0, §6 and §8 for the reasoning |
| `[4] Host environment` | Whether this is WSL2, 20 GB+ free disk, `net.core.somaxconn` 4096+ | `[WARN]` — informational. Recommended in production, ignorable in dev |

The `service nginx restart` check in `[3]` is a static grep that guards against restarting nginx with `service` inside a container, which kills the whole container when PID 1 is nginx.

---

#### 10.2 `verify-ngxblocker.sh` — end-to-end nginx bot-blocking verification

Verifies end to end that [nginx-ultimate-bad-bot-blocker](https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker) downloads, integrates and actually blocks. It uses the **gunicorn stack** (`compose/web-service/nginx_gunicorn`) as the test bed — not the PHP stacks, since every stack shares the same nginx image and verifying one is enough.

**Usage**

```bash
cd /path/to/devspoon-web     # repository root
bash script/test/verify-ngxblocker.sh
```

Exit codes: `0` = ALL CHECKS PASSED, `1` = at least one failure (look at the `[FAIL]` lines). On success the last line is a green `ALL CHECKS PASSED`.

**Important side effects — the state it leaves behind**

This script is not read-only. It touches the environment in this order:

1. Starts the gunicorn stack's `webserver redis` **under a dedicated compose project (`-p devspoon-ngxb-test`) with a temporary env-file (`IMAGE_NAMESPACE=devspoon-it`)**, and cleans up only that project with `down -v --remove-orphans` when it finishes — your production `.env` and the production project's `app-data` volume are untouched. But `container_name` and host ports 80/443 are fixed, so a running production gunicorn stack collides: `docker compose stop` it first.
2. **Adds a temporary conf inside the container** (`/etc/nginx/conf.d/zz_blocker_test.conf`) — a server block matching `Host: blocker.test`. The `Cleanup` step removes it and reloads just before the script exits.
3. **Temporary log files** (`/log/nginx/blocker_test_access.log`, `blocker_test_error.log`) — these stay in the host volume (clean up manually if you care).
4. **Calls `update-ngxblocker -c /etc/nginx` manually** — this refreshes globalblacklist.conf and updates its mtime.

Running it directly on a live host causes brief downtime for the gunicorn stack, so **only run it during a maintenance window on a server carrying production traffic**.

**When to run it**

| Trigger | Why |
|---|---|
| Changing the zone name, key, size or rate of `limit_conn_zone` / `limit_req_zone` (`$bot_iplimit`) in `nginx.conf` | A rate-limit policy change can regress the bot-blocking integration |
| Right after a **manual** `update-ngxblocker` for `bots.d/ddos.conf` or `globalblacklist.conf` | Manual refreshes outside the six-hourly cron carry a higher regression risk |
| Moving the ngxblocker include lines (`blockbots.conf` / `ddos.conf`) in `sample_nginx*.conf`, or adding another `bots.d/*` file | Confirms the server-context includes went to the right place |
| Rebuilding `docker/nginx/Dockerfile` (changes to install-ngxblocker, ca-certificates, cron setup and so on) | Confirms every baked-in artefact is present |
| Restarting after six months or more without a build or verification | Upstream (`mitchellkrogza/nginx-ultimate-bad-bot-blocker`) can change its format subtly and break the grep patterns |

**Verification steps (A–E)**

| Step | What it looks at |
|---|---|
| **A** Start the stack | `up -d webserver redis` under the dedicated project, `nginx -t` passes (only that project is `down -v`'d at the end) |
| **B** Downloaded artefacts | `globalblacklist.conf` ≥ 400 KB, 1000+ bot regex patterns, eight known bots present (MJ12, Ahrefs, Semrush, DotBot, BLEX, Scrapy, nikto, sqlmap), all nine `bots.d/` files exist |
| **C** nginx integration | `nginx.conf` includes `globalblacklist.conf` exactly once, `$bad_bot` is defined, `nginx -t` syntax/test OK, master + ≥ 2 workers |
| **D** cron / update | The `update-ngxblocker -c /etc/nginx` line is in crontab, the cron daemon runs, a manual update leaves the file intact and the workers healthy after reload |
| **E** End-to-end blocking | With the temporary server block (`blocker.test`) — Mozilla UA → 200, four bot UAs (MJ12 / Ahrefs / Semrush / BLEX) → 444 / 000 / 403, bad referer (semalt.com) blocked (optional), access log written |

In `E-4` the bot UA sometimes shows `000` instead of `444`. That means nginx closed the connection without a response and curl received nothing — it counts as the same PASS.

---

#### Quick guide by scenario

| Scenario | Command |
|---|---|
| First diagnosis after setting up a new dev environment | `bash script/test/preflight.sh` |
| Regression check right after an OS / Docker update | `bash script/test/preflight.sh` |
| After changing the rate limits in `nginx.conf` or anything in `bots.d/*` | `bash script/test/verify-ngxblocker.sh` |
| After rebuilding `docker/nginx/Dockerfile` | `bash script/test/verify-ngxblocker.sh` |
| Both in sequence (setup → bot-blocking verification) | `bash script/test/preflight.sh && bash script/test/verify-ngxblocker.sh` |

When you need a new regression asset, add it to the same folder as `verify-<topic>.sh` or `preflight-<topic>.sh` to keep the naming consistent.

---

### 10.3 `script/test_run/` — the staged regression battery

Where `script/test/` (§10) is for "verify one area quickly", `script/test_run/` is an **end-to-end regression battery ordered by stage number (s0/s1b/s2/s3/s5/s6)**. It lets you run the same regression scenario over the whole stack repeatedly.

#### Contents

| Stage | Script | Area verified | Notes |
|---|---|---|---|
| **s0** | `s0_prereq.sh` | docker / docker compose versions, host ports (80/443/5555) free, `log/<service>/` present, `uv` installed, `www/django_sample` uv sync | Pre-check (close to read-only) |
| **s1b** | `s1b_exit_check.sh` | Exit codes and log patterns when a container dies abnormally | Diagnostic |
| **s1b** | `s1b_nginx_conf_generators.sh` | Whether `nginx_http_conf.sh` / `nginx_https_conf.sh` produce correct output for all five stacks (gunicorn / uvicorn / uwsgi / php-7.3 / php-8.4) — missing substitutions, empty placeholders, file permissions | conf generator regression |
| **s2** | `s2_build.sh` | Builds each stack's Dockerfile in isolation with `docker build -f` (both php-fpm 7.3 and 8.4 variants), tagged `devspoon-test/*` | Build regression, independent of the compose layer |
| **s2a** | `s2a_image_inspect.sh` | Base-layer consistency of the built images, ENV / WORKDIR / CMD | Image metadata |
| **s3** | `s3_stack_smoke.sh <stack> <appname> <appcontainer> <stack_name>` | Start one stack → `nginx -t` → `curl -H "Host: ..."` returns 200 → cleanup | Per-stack smoke test |
| **s5** | `s5_https.sh <stack>` | The HTTPS side: dhparam creation/mount/restore, self-signed certificate generation, verification of the substituted `sample_nginx_https.conf`, `nginx -t` passing — **certbot issuance excluded** (assumes an environment with no domain) | HTTPS consistency |
| **s6** | `s6_regression.sh` | Integrated regression — calls every stage above in order and prints a combined result | Nightly regression |
| Helper | `ssl_diag.sh` | Checks the dhparam path and contents, and that the host backup matches the container's copy | Automates the dhparam persistence section of §3 |
| Helper | `verify_block.sh` | Checks bot/scanner blocking (partly overlapping verify-ngxblocker in §10.2) | |
| Helper | `verify_compose_yml.sh` | Static check of the six stacks' docker-compose.yml for the dhparam mount and anti-patterns (mounting ssl/certs, undefined ulimits) | Static regression |
| Helper | `verify_dhparam_lifecycle.sh` / `verify_dhparam_host_wins.sh` | dhparam stages A/B/C — backup, restore and host-wins verification (randomised PORT, stronger polling) | §3 dhparam |
| Helper | `verify_healthcheck.sh` | Static verification of the app/webserver healthchecks and `depends_on: service_healthy` across the six stacks, plus one stack at runtime (nginx_php-8.4 by default; run-ci does the static part only) | §0.5 healthcheck |
| Helper | `verify_nginx_standalone.sh` | Starts a real nginx container with every mount and extracts dhparam with `docker cp` even from a stopped container | dhparam integration |
| **Integration** | `verify_integration_<stack>.sh` × 6 | **Full-stack integration verifiers for all six stacks** — `compose up --wait`, HTTP 200 (`Host: localhost`), 403 on dotfiles, bot UA blocked, rapid requests from a normal UA not blocked, app healthy over a stabilisation window (`STABLE_WINDOW`), celery and beat started with a broker ping on Python stacks, DEBUG off, and more — see the `check` lines in each script for the per-stack assertions | gunicorn / uvicorn / uwsgi / daphne / php73 / php84 |
| Helper | `celery_diag.sh` / `check_cgi.sh` / `check_cgi2.sh` / `check_excode.sh` / `inspect_orphans.sh` / `sim_exit.sh` | Individual diagnostic helpers | One-off |

#### How to run

```bash
# stage by stage (s0 → s2 → s3 → s5 → s6)
cd /path/to/devspoon-web     # repository root
bash script/test_run/s0_prereq.sh

# smoke-test one stack (gunicorn)
bash script/test_run/s3_stack_smoke.sh nginx_gunicorn gunicorn gunicorn-app gunicorn

# HTTPS verification for one stack (no domain, certbot excluded)
# arguments: STACK_DIR  STACK  WEBROOT  APPNAME  SERVICE_PORT
bash script/test_run/s5_https.sh nginx_gunicorn gunicorn django_sample gunicorn-app 8000

# dhparam persistence verification (automates the dhparam section of §3)
bash script/test_run/ssl_diag.sh

# full regression
bash script/test_run/s6_regression.sh

# === full-stack integration verifiers (6 stacks, end-to-end) ===
# automatic .env setup + compose up + wait for healthcheck + HTTP 200 + gzip + privilege drop + dhparam
bash script/test_run/verify_integration_gunicorn.sh
bash script/test_run/verify_integration_uvicorn.sh
bash script/test_run/verify_integration_uwsgi.sh
bash script/test_run/verify_integration_daphne.sh
bash script/test_run/verify_integration_php73.sh
bash script/test_run/verify_integration_php84.sh
```

#### Caution — environment assumptions

- The scripts compute `ROOT` from their own location (`script/test_run/../..`), so they run from any clone path.
- `s5_https.sh` **assumes a local environment with no domain** — it never attempts certbot issuance and only verifies dhparam, the nginx https sample and path consistency.
- `s3_stack_smoke.sh` starts and stops containers, so only run it during a maintenance window on a production host.
- **On a WSL2 host** you may need to re-check `chmod 644 compose/web-service/*/redis/conf/redis.conf` (and the other bind-mount targets) right before running `script/test_run/*.sh`. WSL's default `fmask=177` policy truncates them to 0600, and then redis inside the container cannot read its conf. For a permanent fix, see the `/etc/wsl.conf` settings in §11 (WSL2 host operations guide).

---

### 11. WSL2 host operations guide

This project broadly assumes a dev scenario of **Windows + WSL2 (Ubuntu)** running docker. WSL2's default mount options repeatedly truncate the permissions of bind-mounted paths and break things, so this section collects the fixes.

> For production, use **native Linux or a cloud VM** where possible. WSL2 is for dev and verification.

#### 11.1. Recommended `/etc/wsl.conf` settings

WSL2 mounts `/mnt/c` with `fmask=177` by default (0600 — owner read/write only). With that, the container cannot **read** any bind-mounted file — `redis.conf` (needs 0644), `www/php_sample/index.php` (needs 0644), `nginx.conf` and the rest — and exits immediately ("Permission denied", "Failed to open log file" and similar).

Add this to `/etc/wsl.conf` in the WSL2 instance (create the file if it does not exist).

```ini
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
```

- `metadata` : lets the Linux side store chmod/chown metadata on Windows NTFS.
- `umask=22` : directories default to 0755; `fmask=11` : files default to 0644 (so mounted files appear as 0644).

Then, from PowerShell:

```powershell
wsl --shutdown
# restart the WSL terminal → the new mount options apply
```

Verify:

```bash
mount | grep '/mnt/c'
# → the options should show "umask=22,fmask=11"
ls -l compose/web-service/nginx_gunicorn/redis/conf/redis.conf
# → should show -rw-r--r-- (0644)
```

#### 11.2. The dhparam host backup is owned by root (see §3)

Under WSL, the container's dhparam backup hook writes into the host directory (`./ssl/dhparam/`), and the file ends up **owned by root inside the container**. A non-root host user cannot edit it directly. When you need to change it:

```bash
# work inside the container
docker compose exec webserver sh -c 'rm /etc/nginx/dhparam-backup/dhparam.pem'

# or use sudo on the WSL host
sudo rm compose/web-service/nginx_gunicorn/ssl/dhparam/dhparam.pem
```

#### 11.3. `/mnt/c` performance under WSL

The 9P/Plan9 mount at `/mnt/c` is roughly 10× slower for IO than native ext4. It is the main reason container builds drag during development — more a productivity tip than an operations rule, but move the project to `~/projects/devspoon-web` (WSL2 native ext4) if you can (the scripts compute ROOT automatically).

#### 11.4. healthcheck timing under WSL

On WSL2 the time from container start to the first successful healthcheck can be longer than on native Linux. compose's `start_period: 30s` leaves some margin, but it may not be enough when the WSL host is under memory pressure. In that case the webserver fails with `dependency failed to start: container ... is unhealthy` — raise the timeout to around 60s once, then put it back when things settle.

---

## Community

- **Website** : Owner's personal website is devspoon.com

## Partners and Users

- Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com
