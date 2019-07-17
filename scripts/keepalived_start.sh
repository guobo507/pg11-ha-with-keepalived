#!/usr/bin/env bash

if [ `whoami` != 'root' ]; then
    echo -e "ERR! Only root can startup keepalived daemon... "\\n
    exit 11
fi

KEEPALIVED_CONF='/etc/keepalived/keepalived.conf'

if [ `ps -ef |grep -v grep |grep "$KEEPALIVED_CONF" |wc -l` -ne 0 ]; then
    echo -e "Keepalived is already running... "\\n
    ps -e |grep keepalived
    exit 1
else
    echo -n "Starting keepalived daemon... "
    /usr/sbin/keepalived -f $KEEPALIVED_CONF -D -d -S 1 &> /dev/null
    if [ $? -ne 0 ]; then
        echo -e "Failed!"\\n
        exit 1
    else
        echo -e "OK!"\\n
        exit 0
    fi
fi
