#!/bin/bash
service=sshd

if (( $(netstat -tlnp | grep 22 | grep -v grep | grep $service | wc -l) > 0 ))
then
echo "$service is running!!!"
else
/etc/init.d/$service start
fi
