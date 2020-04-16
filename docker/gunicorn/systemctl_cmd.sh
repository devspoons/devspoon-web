#!/bin/bash

while true
do
    sleep 5
    result=$(ps -ax|grep -v grep|grep systemd-journald)
    if [ "${#result}" -ne 0 ]
    then
        echo 'systemctl daemon-reload'
        echo 'systemctl start gunicorn'
        echo 'systemctl enable gunicorn'
        break
    else
        echo "${#result}"
    fi
done
