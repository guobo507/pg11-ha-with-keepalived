#!/usr/bin/env bash

if [ `whoami` != 'root' ]; then
    echo -e "ERR! Only root can stop keepalived daemon... "\\n
    exit 11
fi

KEEPALIVED_CONF='/etc/keepalived/keepalived.conf'

if [ `ps -ef |grep -v grep |grep "$KEEPALIVED_CONF" |wc -l` -eq 0 ]; then
    echo -e "Keepalived is already stoped... "\\n
else
    echo -n "Shutting down keepalived daemon... "
    /usr/bin/killall -9 keepalived &> /dev/null
    if [ $? -ne 0 ]; then
        echo -e "Failed!"\\n
        exit 1
    else
        echo -e "OK!"\\n
        exit 0
    fi
fi
