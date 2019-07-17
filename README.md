# pgsql11-ha-with-keepalived
PostgreSQL 11.2高可用集群：Stream Replication + Keepalived HA

## 1 Environment

### 1.1 Server environment:

- HOSTNAME:pgsql1  NETWORK:eth1:10.128.0.11/24（eth2:172.16.0.11/24，流复制网络） OS:CentOS7.6
- HOSTNAME:pgsql2  NETWORK:eth1:10.128.0.12/24（eth2:172.16.0.12/24，流复制网络） OS:CentOS7.6
- Virtual IP: 10.128.0.10/24(eth1:1)

### 1.2 Software/Packages:

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

### 1.3 User environment setting

Add the following lines to `/home/postgres/.bash_profile` for both server: 

    ```
    export PGHOME=/usr/pgsql-11
    export PGDATA=/u01/pgdata/11
    export PATH=$PGHOME/bin:$PATH
    export PGCONF=$PGDATA/postgresql.conf
    export PGHBA=$PGDATA/pg_hba.conf
    ```

Modify `/etc/hosts` file, add the following lines:

    10.128.0.11    pgsql1
    10.128.0.12    pgsql2
    172.16.0.11    pgsql1-priv
    172.16.0.12    pgsql2-priv
    10.128.0.10    pgsql-vip

## 2 Install PostgreSQL and Keepalived on both node

### 2.1 Adjusting kernel parameter


    cat <<EOF >> /etc/sysctl.conf
    vm.overcommit_memory=2
    vm.overcommit_ratio = 70
    vm.nr_hugepages=2048
    EOF

    sysctl -w vm.nr_hugepages=2048
    sysctl -p

### 2.2 Setting `/etc/security/limits.conf`

    cat <<EOF >> /etc/security/limits.conf
    @postgres   soft    nofile  4096
    @postgres   hard    nofile  65536
    @postgres   soft    nproc   16384
    @postgres   soft    stack   10240
    EOF

### 2.3 Create postgres user and group

    groupadd -g 5432 postgres
    useradd -u 5432 -g postgres postgres
    echo pguser_password |passwd --stdin postgres

### 2.4 Install `postgresql11-server` and `keepalived` packages

    rpm -ivh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    yum clean all && yum makecache
    yum install -y postgresql11-server-11.2-2PGDG.rhel7.x86_64 postgresql11-contrib-11.2-2PGDG.rhel7.x86_64
    yum install -y keepalived

## 3 Create PostgreSQL server on pgsql1

### 3.1 Create PGDATA directory and run initdb

    mkdir -p /u01/pgdata/11
    chown -R postgres.postgres /u01/pgdata
    chmod 700 /u01/pgdata/11
    su - postgres
    echo 'postgres_password' > /u01/pgdata/.super_password
    /usr/pgsql-11/bin/initdb --pgdata=/u01/pgdata/11  --encoding=UTF8 --locale=C --username=postgres --pwfile=/u01/pgdata/.super_password

### 3.2 Setting some alias for PG server management

    cat << EOF >> ~/.bash_profile
    alias start_pgsql11='/usr/pgsql-11/bin/pg_ctl -D /u01/pgdata/11 -l /u01/pgdata/11/postgresql.log start'
    alias stop_pgsql11='/usr/pgsql-11/bin/pg_ctl -D /u01/pgdata/11 -l /u01/pgdata/11/postgresql.log stop -m fast'
    alias restart_pgsql11='/usr/pgsql-11/bin/pg_ctl -D /u01/pgdata/11 -l /u01/pgdata/11/postgresql.log restart'
    alias reload_pgsql11='/usr/pgsql-11/bin/pg_ctl -D /u01/pgdata/11 -l /u01/pgdata/11/postgresql.log reload'
    EOF
    source ~/.bash_profile

### 3.3 Adjusting parameter of PostgreSQL server



### 3.4 Start PostgreSQL server on pgsql1 node

    start_pgsql11

## 2 Setup Stream Replication

### 2.1 On server pgsql1

Create replication user and slot:

    su - postgres
    psql -U postgres -d postgres
    CREATE USER replman REPLICATION LOGIN CONNECTION LIMIT 5 ENCRYPTED PASSWORD 'replman';
    SELECT * FROM pg_create_physical_replication_slot('pg_replslot_001');
    select slot_name,plugin,slot_type,temporary,active from pg_replication_slots;
    \q

Modify `pg_hba.conf`:

    echo "host    replication    replman    10.128.0.0/24    md5" >> $PGHBA
    echo "host    all            pgpool     10.128.0.0/24    md5" >> $PGHBA

Restart PG server to take effect.

### 2.2 On server pgsql2

Get the base full backup from pgsql1 node:

su - postgres
mkdir /u01/pgdata/11
chown -R postgres.postgres /u01/pgdata
chmod 700 /u01/pgdata/11
pg_basebackup -D /u01/pgdata/11 -U replman -h c7pgsql1 -p 5432 -X stream -F p -c fast -W -R -v
cat <<EOF >> ./recovery.conf
recovery_target_timeline = 'latest'
#trigger_file = '/tmp/.TRIGGER.PGSQL.5432'
primary_slot_name = 'pg_replslot_001'
EOF

#sed -i "/^max_connections/s/128/140/g" $PGCONF
~/scripts/postgresql_start.sh
tail -n 20 $PGDATA/log/postgresql-*.log

psql -U postgres -c "SELECT * FROM pg_create_physical_replication_slot('pg_replslot_001');"
psql -U postgres -c "SELECT * FROM pg_create_physical_replication_slot('pg_replslot_002');"
psql -U postgres -c "select slot_name,plugin,slot_type,temporary,active from pg_replication_slots;"






