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

## Install & Run

1. Make webroot folder

   ```
   User have to make new folder under www path

   Example : /www/home_test
   ```

2. Make a conf file of nginx

   - PHP service

     - **PHP service installation [nginx for php]**

       ```
       In config/web-server/php
       There are 2 shell script
       Use "chmod +x xxxx.sh" command, you activate shell script and run. then it make conf file
       nginx's a conf file will be in conf.d folder
       if your webroot path has sub-level, input type must be following as "\\/www\\/shop\\/shop_kings
       ```

       ```
       Shell script required informations like bellow
       webroot : ex -> shop_kings
       domain : ex -> xxxx.com
       portnumber : ex -> 80
       appname : ex -> php-app (user must be use "container name" referenced in docker-compose.yml file)
       serviceport : ex -> 9000 (php application service port)
       filename : ex -> xxxx (it's the name for nginx's conf file)
       ```

     - **PHP service installation [php application]**

       ```
       In config/app-server/php
       There are 1 shell script
       Use "chmod +x xxxx.sh" command, you activate shell script and run.sh then it make conf file
       nginx's a conf file will be in pool.d folder
       ```

     - **Run docker-compose.yml**

       ```
       Get move to compose/nginx_php
       Execute docker-compose.yml using "docker-compose up -d" command
       If you want to run redis, redis-stats, use "docker-compose --profile redis up -d".
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
       Get move to compose/nginx_gunicorn
       Run docker-compose.yml using the “docker-compose up -d” command.
       If you want to run celery, celerybeat, and flower, use "docker-compose --profile celery up -d".
       If you want to run redis-stats, use "docker-compose --profile redis up -d".
       To run all services, use "docker-compose --profile celery --profile redis up -d".
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
       Get move to compose/nginx_uwsgi
       Execute docker-compose.yml using "docker-compose up -d" command
       If you want to run celery, celerybeat, and flower, use "docker-compose --profile celery up -d".
       If you want to run redis-stats, use "docker-compose --profile redis up -d".
       To run all services, use "docker-compose --profile celery --profile redis up -d".
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
