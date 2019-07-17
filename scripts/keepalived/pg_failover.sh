#!/usr/bin/env bash

export LANG=en_US.UTF-8
export PGPORT=5432
export PGUSER=pgmonitor
export PG_OS_USER=postgres
export PGDBNAME=pgmonitor
export PGHOME=/usr/pgsql-11
export PGDATA=/u01/pgdata/11
export PATH=$PGHOME/bin:$PATH

LOGFILE=/var/log/keepalived/keepalived_pg.log

PROMOTE_COMMAND="$PGHOME/bin/pg_ctl promote -D $PGDATA"

echo -e `date +"%F %T"` "`basename $0`: [INFO] Checking if there needs a promote operation... " >> $LOGFILE

SQL1="select pg_is_in_recovery from pg_is_in_recovery();"
SQL2="select last_alive from cluster_status where now()-last_alive > interval '60';"

DB_ROLE=`echo $SQL1 |$PGHOME/bin/psql -At -p $PGPORT -U $PGUSER -d $PGDBNAME -w`

# If current node is in PRIMARY mode, then do nothing. Otherwise, promote it to PRIMARY mode.
if [ $DB_ROLE == 'f' ]; then
    echo -e `date +"%F %T"` "`basename $0`: [WARN] PostgreSQL is running in PRIMARY mode." >> $LOGFILE
    exit 0
elif [ $DB_ROLE == 't' ]; then
    echo -e `date +"%F %T"` "`basename $0`: [WARN] PostgreSQL is running in STANDBY mode, ready to promote..." >> $LOGFILE
fi

# Prerequisites for an PRIMARY and STANDBY switching:
#   1 Current node must be in STANDBY mode.
#   2 Delay-time between PRIMARY and STANDBY nodes must be as small as possible(60s).

STANDBY_DELAY=`echo $SQL2 |$PGHOME/bin/psql -At -p $PGPORT -U $PGUSER -d $PGDBNAME -w`
if [ -z $STANDBY_DELAY ] && [ $DB_ROLE == 't' ]; then
        echo -e `date +"%F %T"` "`basename $0`: [WARN] Promote the current node to PRIMARY mode..." >> $LOGFILE
        su - $PG_OS_USER -c "$PROMOTE_COMMAND"
        if [ $? -eq 0 ]; then
                echo -e `date +"%F %T"` "`basename $0`: [INFO] Promote the current node to PRIMARY mode success." >> $LOGFILE
                exit 0
        else
                echo -e `date +"%F %T"` "`basename $0`: [ERR] Promote the current node to PRIMARY failed, check logfile for details." >> $LOGFILE
                exit 0
        fi
else
    echo -e `date +"%F %T"` "`basename $0`: [WARN] Stream replication delay time is about: $STANDBY_DELAY""s." >> $LOGFILE
    echo -e `date +"%F %T"` "`basename $0`: [ERR] STANDBY node is too far behind the MASTER node, you must repair the cluster manually" >> $LOGFILE
    exit 1
fi
