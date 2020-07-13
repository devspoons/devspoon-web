# devspoon-web
This open source project offer docker that three kind of web service solutions by php-7.3, gunicorn, uwsgi based on nginx server.  
Anyone can install web services easily using docker and docker-compose.  
Af you want to use python and php service at same time, this solution can help you better.

이 오픈소스 프로젝트는 nginx 서버를 기반으로 한 PHP, gunicorn, uwsgi의 세 가지 웹 서비스 솔루션을 docker로 제공합니다.  
누구나 docker 및 docker-compose를 사용하여 웹 서비스를 쉽게 설치할 수 있습니다.  
파이썬과 PHP 서비스를 동시에 사용하려면이 솔루션이 더 도움이 될 수 있습니다.

## Features

* **Support to make configuration files for each service(conf, yml etc)** : Using shell script, you can easily make and manage the configuration files required for nginx, php, dockerfile, etc. with only the information required by the user's keyboard.

* **Efficiently  dockerfile configuration for development and service operation** : The log folder is interlocked by "volumes" in docker-compose.yml so that user can can be tracked problems even when the docker container is stopped. Webroot, nginx config, etc. are frequently modified during development so these are interlocked by "volumes" 

* **Provide reverse proxy function** : Multiple web and app services can be provided through one nginx with php or python and services can be provided simultaneously. A shell script is provided to easily create a proxy config file so that it can be integrated with the web UI of other services.

* **Provides easy distributed service operation method** : You can use multiple web servers through proxy, and you can use multiple app servers on one web server. (How to set load balancing will be supported in the future)

* **각 서비스들의 환경설정 파일 생성 지원(conf, yml etc)** : shell script를 이용해 nginx, php, dockerfile 등에 요구되는 환경설정 파일들을 필수적으로 요구되는 정보들만 사용자의 키보드로 입력받아 쉽게 만들고 관리할 수 있습니다.
  
* **개발 및 서비스 운영에 효율적인 dockerfile 구성** : docker container가 중지된 경우에도 문제를 추적할 수 있도록 log 폴더를 volumes으로 연동되어 있으며 Webroot, nginx의 config 등 개발시 수정이 빈번하게 발생되는 항목들에 대해서도 volumes으로 연동되어 있습니다.
  
* **Reverse proxy 기능 제공** : 하나의 nginx를 통해 여러개의 web, app 서비스를 제공하거나 php 혹은 python의 서비스를 동시에 제공할 수 있습니다. 다른 서비스의 웹 UI와 연동될 수 있도록 proxy config 파일을 쉽게 생성할 수 있도록 쉘 스크립트를 제공합니다.
  
* **쉬운 분산 서비스 운영 방법 제공** : proxy를 통해 여러대의 웹 서버를 사용할 수 있으며 하나의 웹 서버에서 여러대의 앱 서버를 사용할 수 있습니다. (부하분산을 설정 방법 차후 지원 예정)

## Considerations

* **No DB service** : This open source does not provide DB as docker to suggest stable operation. It is recommended to install it on a real server and access it using a network, such as port 3306. We hope that this will be done for distributed services as well. We hope that this will be consider for distributed services as well.

* **Development-oriented docker service** : This open source is designed for focused on development-oriented rather than perfect docker container distribution and is suitable for startups or new service development teams with frequent initial modifications and tests.

* **Orchestration not supported** : In the future, we plan to interoperate with cloud services such as AWS and GCM

* **This open-source considers generic servers that are not support AWS, GCM** : This open source is intended to be installed and operated on a server that is directly operated, and on general server hosting, and plans to integrate with cloud services such as AWS and GCM in the future

* **DB 서비스 없음** : 이 오픈소스는 안정적인 운영을 제안하기 위해 DB는 docker로 제공하지 않습니다. 실제 서버에 설치하여 3306 포트 등으로 네트워크를 이용해 접근하는 것을 권장합니다. 분산 서비스를 위해서라도 이와 같이 구성하기를 바랍니다.
  
* **개발 중심적 docker 서비스** : 이 오픈소스는 완전한 docker container의 배포가 아닌 개발 중심적으로 설계되었으며 초기 수정과 테스트가 빈번한 스타트업 혹은 신규 서비스 개발팀에게 적합합니다.
  
* **오케스트레이션 미지원** : 앞으로 AWS, GCM 등의 Cloud 서비스와 연동할 계획이며 이후 오케스트레이션이 지원될 예정입니다.
  
* **AWS, GCM 기반이 아닌 일반 서버 고려** : 이 오픈소스는 직접 운용하고있는 서버, 일반적인 서버 호스팅에서 설치하여 운영하는 것을 목적으로 하고 있으며 앞으로 단계적으로 AWS, GCM 등의 Cloud 서비스와 연동할 계획입니다.


## Install & Run

1. Make webroot folder
      ```
      User have to make new folder under www path

      Example : /www/home_test
      ```


2. Make a conf file of nginx
 
### PHP service
***

   * **PHP service installation [nginx for php]**
      ```
      In config/web-server/php
      There are 2 shell script
      Use "chmod +x xxxx.sh" command, you activate shell script and run. then it make conf file
      nginx's a conf file will be in conf.d folder
      ```

      ```
      Shell script required informations like bellow
      webroot : ex -> /www/xxxx 
      domain : ex -> xxxx.com
      portnumber : ex -> 80
      appname : ex -> php-app (user must be use "container name" referenced in docker-compose.yml file)
      serviceport : ex -> 9000 (php application service port)
      filename : ex -> xxxx (it's the name for nginx's conf file)
      ```

  
   * **PHP service installation [php application]**

      ```
      In config/app-server/php
      There are 1 shell script
      Use "chmod +x xxxx.sh" command, you activate shell script and run.sh then it make conf file
      nginx's a conf file will be in pool.d folder
      ```

   * **Run docker-compose.yml**
      ```
      Get move to compose/nginx_php
      Execute docker-compose.yml using "docker-compose up -d" command
      ```
    
### Gunicorn service
***
   * **Municorn service installation [nginx for gunicorn]**
      ```
      In config/web-server/gunicorn
      There are 2 shell script
      Use "chmod +x xxxx.sh" command, you activate shell script and run.sh then it make conf file
      nginx's a conf file will be in conf.d folder
      ```

      ```
      Shell script required informations like bellow
      webroot : ex -> /www/xxxx 
      domain : ex -> xxxx.com
      portnumber : ex -> 80
      appname : ex -> gunicorn-app (user must be use "container name" referenced in docker-compose.yml file)
      serviceport : ex -> 8000 (gunicorn application service port)
      filename : ex -> xxxx (it's the name for nginx's conf file)
      ```

   * **Gunicorn service installation [gunicorn application]**

      ```
      * If user want to use config.py, user have to modify run.sh file in docker/gunicorn/
      In docker/gunicorn/
      There are 1 shell script, run.sh

      And user have to consider two lines

      1) cd /www/py37/django_test/repo 
      #User have to move work directory to the project root

      2) gunicorn --workers 4 --bind 0.0.0.0:8000 conf.wsgi:application --daemon --reload 
      #User have to consider service port number and worker (cpu core * 2)
      ```

   * **Run docker-compose.yml**
      ```
      Get move to compose/nginx_gunicorn
      Execute docker-compose.yml using "docker-compose up -d" command
      ```

### UWSGI service
***
   * **UWSGI service installation [nginx for uwsgi]**
      ```
      In config/web-server/uwsgi
      There are 2 shell script
      Use "chmod +x xxxx.sh" command, you activate shell script and run.sh then it make conf file
      nginx's a conf file will be in conf.d folder
      ```

      ```
      Shell script required informations like bellow
      webroot : ex -> /www/xxxx 
      domain : ex -> xxxx.com
      portnumber : ex -> 80
      appname : ex -> uwsgi-app (user must be use "container name" referenced in docker-compose.yml file)
      serviceport : ex -> 8000 (uwsgi application service port)
      filename : ex -> xxxx (it's the name for nginx's conf file)
      ```

   * **UWSGI service installation [uwsgi application]**

      ```
      In config/app-server/uwsgi
      There are a file named uwsgi.ini

      Referred comment, user can modify project root path, port number etc
      * There are sample project in www/py37/ folder. user can referenced it
      ```

   * **Run docker-compose.yml**
      ```
      Get move to compose/nginx_uwsgi
      Execute docker-compose.yml using "docker-compose up -d" command
      ```
***

## How to develop based on working server

* User can access using defined folders in docker-compose.yml

      Example -> nginx container has volumes like below that
            
      /www
      /script/
      /etc/nginx/conf.d/
      /etc/nginx/nginx.conf
      /etc/nginx/uwsgi_params
      /ssl/
      /log

      If user run containers at same server, can update code and move files directly from local server folder to container folder.       

* If user use firewall, have to add required port number (refer each docker-compose.yml files)

      Example

      ufw allow 80/tcp
      ufw allow 3306/tcp

## Setting up HTTPS on a web server
* This step requires running http nginx server

      1. There are letsencrypt.sh shell script file in script folder and it interlocked by volumes.
      So user can access script file in a nginx container.

      2. Use "docker exec -it <nginx container name> bash" command, user can get docker inside.
      
      3. Run letsencrypt.sh and insert informations such as webroot, domain, e-mail etc.
         This script make ssl-key and make crontab schedule automatically

      4. Using "exit" command user can get off from container
      
      5. Run nginx_https_conf.sh existing. it make conf file under config/web-server/<service>

      6. User have to remove http conf file in config/web-server/<service>/conf.d/

      7. Run "docker-compose up" command in the compose folder


## Community

* **Personal Website :** Owner's personam website is [devspoon.com]
* **Github.io :** Ther are more detail guide [devspoon.github.io]

## Demos

* **[youtube]** - Preparing
* **[inflearn]** - Demos for Devspoon features and how to use the devspoon's open-source

## Partners and Users

* Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com  
Personal github.io : [bluebamus.github.io]

* 임도현 Owner 개발자/기획자, bluebamus@gmail.com  
개인 github.io 사이트 : [bluebamus.github.io]

<!-- Markdown link & img dfn's -->
[devspoon.github.io]: https://github.com/devspoons/devspoon.github.io
[wiki]: https://github.com/yourname/yourproject/wiki
[youtube]: https://www.youtube.com/
[inflearn]: https://www.inflearn.com/
[bluebamus.github.io]: bluebamus.github.io