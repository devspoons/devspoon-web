#!/bin/bash

my_array=()
delimiter="-d"
domain_string=""

# cron / certbot / python3-certbot-nginx / ca-certificates 는 nginx Dockerfile 에서 설치된다.
# 이 스크립트는 컨테이너 내부에서 1회성 초기 발급용으로 실행되므로 추가 설치는 불필요.
# 외부 호스트에서 단독 실행 시에는 아래 라인의 주석을 해제해서 사용한다.
# apt-get update && apt-get install -y sendmail wget vim cron certbot python3-certbot-nginx ca-certificates
while :
do 
    echo -n "Enter the service webroot_folder >"
    read webroot_folder
    echo  "Entered service webroot_folder: $webroot_folder"
    if [[ "$webroot_folder" != "" ]]; then
        break
    fi
done 

while :
do 
    echo -n "To add a subdomain, type something like 'aaa.com www.aaa.com sub.aaa.com', but all domains refer to the same web root"
    echo -n "A domain in aaa.com format must be entered first."
    echo -n "Enter the service domain >"
    read domain
    echo  "Entered service domain: $domain"
    if [[ "$domain" != "" ]]; then
        break
    fi
done 

IFS=' ' read -ra my_array <<< "$domain"

while :
do 
    echo -n "Enter the user e-mail >"
    read mail
    echo  "Entered user e-mail: $mail"
    if [[ "$mail" != "" ]]; then
        break
    fi
done 

for element in "${my_array[@]}"; do
    domain_string+=" $delimiter $element"
done

# Remove leading space
# domain_string="${domain_string# }"

# for element in "${my_array[@]}"; do
if ! test -f /ssl/${my_array[0]}/dhparam.pem ; then
    if ! test -f /etc/ssl/certs/${my_array[0]}/dhparam.pem ; then
        echo "try to create ssl key using openssl "
        if ! test -d /etc/ssl/certs/${my_array[0]}/ ; then
            echo "create "${my_array[0]}" folder: /etc/ssl/certs/"${my_array[0]}"/"
            mkdir -p /etc/ssl/certs/${my_array[0]}/
        fi
        openssl dhparam -out /etc/ssl/certs/${my_array[0]}/dhparam.pem 4096
        if ! test -d /ssl/${my_array[0]}/ ; then
            echo "create "${my_array[0]}" folder: /ssl/"${my_array[0]}"/"
            mkdir -p /ssl/${my_array[0]}/
        fi
        cp /etc/ssl/certs/${my_array[0]}/dhparam.pem /ssl/${my_array[0]}/ -r
    # else
    #     echo "copy ssl folder by already maden"
    #     cp /ssl/certs/$domain/dhparam.pem /etc/ssl/certs/dhparam.pem -r
    fi
else
    if ! test -d /etc/ssl/certs/${my_array[0]}/ ; then
        echo "create "${my_array[0]}" folder: /etc/ssl/certs/"${my_array[0]}"/"
        mkdir -p /etc/ssl/certs/${my_array[0]}/
    fi
    cp /ssl/${my_array[0]}/dhparam.pem /etc/ssl/certs/${my_array[0]}/ -r
fi
# done

#if ! test -d /etc/letsencrypt/live/test.com ; 
if ! test -d /etc/letsencrypt/${my_array[0]}/letsencrypt ; then 
    echo "try to create authentication key using certbot "
    certbot certonly --non-interactive --agree-tos --email $mail --webroot -w /www/$webroot_folder$domain_string
    echo "certbot certonly --non-interactive --agree-tos --email "$mail" --webroot -w /www/"$webroot_folder$domain_string
    # if ! test -d /ssl/letsencrypt/$domain/ ; then
    #     echo "create domain folder: /ssl/letsencrypt/"$domain"/"
    #     mkdir -p /ssl/letsencrypt/$domain/
    # fi
    #cp /etc/letsencrypt/ /ssl/letsencrypt/$domain/ -r
# else
#     echo "copy letsencrypt folder by already maden"
#     cp /ssl/letsencrypt/$domain/ /etc/letsencrypt/ -r
fi

# certbot 자동 갱신 cron 은 nginx Dockerfile 에 이미 등록되어 있다.
# 컨테이너 안에서는 'nginx -s reload' (master 프로세스에 SIGHUP 전송, graceful reload) 가 정답이며
# 'service nginx restart' 는 PID 1 = nginx 인 컨테이너에서는 동작하지 않거나 의도치 않은 재시작을 유발하므로 사용 금지.
# → 중복/충돌 방지를 위해 letsencrypt.sh 의 crontab 자동 등록 라인은 의도적으로 삭제.