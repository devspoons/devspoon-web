# devspoon-web-php
> nginx와 php7.3 기반으로 가상 호스팅을 Docker와 Docker-compose를 이용해 쉽게 구축할 수 있도록 솔루션을 제공한다.

## 서비스 특징

> shell script를 이용해 nginx와 php의 conf 파일을 도메인마다 독립적으로 만들 수 있도록 제공

> nginx와 php의 모든 config 파일을 Docker-compose의 volumes으로 연동시켜 구동 전, 구동 후에도  
  exec로 컨테이너에 들어가지 않고 제어가 가능함
  
> 해당 솔루션은 안전성의 문제로 mysql 등의 DB는 docker로 제공하지 않는다.  
  이에 독립적인 서버가 운영되고 있다는 가정하여 3306 포트를 컨테이너에서 외부로 접근 할 수 있도록 설정한다.  
  - 동일 서버에 설치하고 ip 혹은 서브 도메인 등으로 접근하는 방법을 사용할 것을 
  
> 단점으로는 상위와 같이 개별적인 conf를 작성하는것을 요구하다보니 독립적인 이미지로 만들기 어려움. 

> 만약 외부와의 연동을 배제하고 독립적인 이미지로 구축하고자 한다면 제공되는 shell script로 conf를 만들고  
  Docker 혹은 Docker-compose 파일을 수정하여 컨테이너 내부에 복사하거나 스크립트를 수행하도록 만들면 된다.
  
  * 상위 단점에 제안하는 독립적인 Docker 이미지를 구축하는데 필요한 스크립트 및 방법은 따로 제공할 계획이 없다.


## 사용 방법

1. web site 운영시 소스코드를 저장할 홈 폴더를 생성한다.
```
www 폴더 밑에 원하는 폴더명으로 생성한다

예시 : /www/home_test
```


2. nginx 관련 conf 파일 생성

```
config 폴더에서 nginx_conf.sh, php_conf.sh 파일을 사용하여 각각의 conf 파일을 생성한다.  
nginx conf 파일은 conf.d에 자동으로 생성되고  
php conf 파일은 pool.d에 자동으로 생성된다.
```

```sh
nginx_conf.sh 파일 내용은 다음과 같다.
해당 스크립트는 sample_nginx.conf 파일을 기반으로 입력한 변수를 적용시킨다.

#!/bin/bash

account=$1
domain=$2
portnumber=$3
phpport=$4

sed 's/account/'$account'/' sample_nginx.conf > $account'1'.temp
sed 's/domain/'$domain'/g' $account'1'.temp > $account'2'.temp
sed 's/portnumber;/'$portnumber';/' $account'2'.temp > $account'3'.temp
sed 's/phpport/'$phpport'/' $account'3'.temp > ./conf.d/$account'_ng'.conf 

rm *.temp
```

```sh
사용 방법은 다음과 같다  
nginx_conf.sh 'web-site 홈 폴더명' '도메인' 'web 포트넘버 : 기본 80' 'php 포트넘버 : 기본 9000'  
nginx_conf.sh home_test home.com 80 9000
```

3. php 관련 conf 파일 생성

```sh
php_conf.sh 파일 내용은 다음과 같다.
해당 스크립트는 sample_php.conf 파일을 기반으로 입력한 변수를 적용시킨다.

#!/bin/bash

account=$1
port=$2


sed 's/account/'$account'/' sample_php.conf > $account'1'.temp
sed 's/port/'$port'/' $account'1'.temp > ./pool.d/$account'_php'.conf

rm *.temp
```

```sh
사용 방법은 다음과 같다  
nginx_conf.sh 'web-site 홈 폴더명' 'php 포트넘버 : 기본 9000'  
nginx_conf.sh home_test 9000
```

4. nginx와 php 기본 설정 conf 파일 중 수정할게 있으면 파일을 변경한다  

```
fastcgi, nginx_conf, php_ini 폴더에 각각의 파일이 있음
```

5. log 폴더에 nginx log가 생성되기 때문에 컨테이너에 들어가지 않아도 실시간 확인이 가능함

6. 우분투의 경우 방화벽에서 80포트와 3306포트를 개방한다. 

```
ufw allow 80/tcp  
ufw allow 3306/tcp
```

7. docker-compose 실행

```
폴더 최상위 docker-compose.yml 파일 위치에서 docker-compose up -d 실행
```

## 사용 예제

스크린 샷과 코드 예제를 통해 사용 방법을 자세히 설명합니다.
- 업데이트 예정

## 개발 환경 설정

만약 Docker 설치와 Docker-compose 설치가 되어 있지 않다면 다음 사항을 확인함

> docker 설치 참고 사이트 [docker-install]  
> docker-compose는 apt-get을 통해 설치가 가능한 것으로 확인됨

## 업데이트 내역

* 0.1.0 : 안정화 버전 완료 / 이후 성능 향상을 위해 nginx 및 php conf 파일들을 커스터 할 예정
    

## 멤버

임도현 Owner S/W, H/W, 개발자/기획자, bluebamus@gmail.com

<!-- Markdown link & img dfn's -->
[docker-install]: https://hcnam.tistory.com/25 
[npm-url]: https://npmjs.org/package/datadog-metrics
[npm-downloads]: https://img.shields.io/npm/dm/datadog-metrics.svg?style=flat-square
[travis-image]: https://img.shields.io/travis/dbader/node-datadog-metrics/master.svg?style=flat-square
[travis-url]: https://travis-ci.org/dbader/node-datadog-metrics
[wiki]: https://github.com/yourname/yourproject/wiki
