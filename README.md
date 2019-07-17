# pgsql11-ha-with-keepalived
PostgreSQL 11.2高可用集群：Stream Replication + Keepalived HA

## 环境

两台服务器：

- pgsql1  eth1:10.128.0.11/24（eth2:172.16.0.11/24，复制网络） CentOS7.6
- pgsql2  eth1:10.128.0.12/24（eth2:172.16.0.12/24，复制网络） CentOS7.6
- Virtual IP: 10.128.0.10/24

软件版本：

- PostgreSQL：

    ```
    # rpm -qa |grep postgresql11
    postgresql11-11.2-2PGDG.rhel7.x86_64
    postgresql11-devel-11.2-2PGDG.rhel7.x86_64
    postgresql11-contrib-11.2-2PGDG.rhel7.x86_64
    postgresql11-libs-11.2-2PGDG.rhel7.x86_64
    postgresql11-server-11.2-2PGDG.rhel7.x86_64
    postgresql11-test-11.2-2PGDG.rhel7.x86_64
    ```

- Keepalived：

    ```
    # rpm -qa |grep keepalived
    keepalived-1.3.5-6.el7.x86_64
    ```

## Setup Replication

### On pgsql1

创建复制用户及复制SLOT：

    su - postgres
    psql -U postgres -d postgres
    CREATE USER replman REPLICATION LOGIN CONNECTION LIMIT 5 ENCRYPTED PASSWORD 'replman';
    SELECT * FROM pg_create_physical_replication_slot('pg_replslot_001');
    select slot_name,plugin,slot_type,temporary,active from pg_replication_slots;
    \q

修改pg_hba.conf文件:

    PGHBA=/u01/pgdata/11/pg_hba.conf
    echo "host    replication    replman    10.128.0.0/24    md5" >> $PGHBA
    echo "host    all            pgpool     10.128.0.0/24    md5" >> $PGHBA

附加配置（根据情况而定）：

    PGCONF=/u01/pgdata/11/postgresql.conf
    sed -i "/^#max_replication_slots/s/^#//g" $PGCONF
    sed -i "/^#wal_sender_timeout/s/^#//g" $PGCONF
    sed -i "/^#hot_standby/s/^#//g" $PGCONF
    sed -i "/^#max_standby_archive_delay/s/^#//g" $PGCONF
    sed -i "/^#max_standby_streaming_delay/s/^#//g" $PGCONF
    sed -i "/^#wal_receiver_status_interval/s/^#//g" $PGCONF
    sed -i "/^#hot_standby_feedback/s/^#//g" $PGCONF
    sed -i "/^hot_standby_feedback/s/off/on/g" $PGCONF
    sed -i "/^#wal_retrieve_retry_interval/s/^#//g" $PGCONF

重启pgsql，让其生效。






