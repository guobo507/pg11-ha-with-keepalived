# pgsql11-ha-with-keepalived
PostgreSQL 11.2高可用集群：Stream Replication + Keepalived HA

## 1 Environment

### 1.1 Server environment

| HOSTNAME | PUBLIC IP | PRIVATE IP | CPU/MEM/DISK | OTHER INFO |
| --------- | --------- | --------- | --------- | --------- |
| pgsql1 | 10.128.0.11/24 | 172.16.0.11/24 | 2C/6G/40GB | CentOS7.6/PostgreSQL 11.2(MASTER) |
| pgsql1 | 10.128.0.11/24 | 172.16.0.11/24 | 2C/6G/40GB | CentOS7.6/PostgreSQL 11.2(STANDBY) |

> **Note:** Virtual IP: 10.128.0.10/24

### 1.2 Package version

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

Add the following lines to `/home/postgres/.bash_profile` for both nodes(please create postgres user first): 

    export PGHOME=/usr/pgsql-11
    export PGDATA=/u01/pgdata/11
    export PATH=$PGHOME/bin:$PATH
    export PGCONF=$PGDATA/postgresql.conf
    export PGHBA=$PGDATA/pg_hba.conf

Modify `/etc/hosts` file on both nodes, add the following lines:

    10.128.0.11    pgsql1
    10.128.0.12    pgsql2
    172.16.0.11    pgsql1-priv
    172.16.0.12    pgsql2-priv
    10.128.0.10    pgsql-vip

## 2 Install PostgreSQL and Keepalived on both nodes

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

### 2.3 Create `postgres` user and group

    groupadd -g 5432 postgres
    useradd -u 5432 -g postgres postgres
    echo pguser_password |passwd --stdin postgres

### 2.4 Install `postgresql11-server` and `keepalived` packages

    rpm -ivh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    yum clean all && yum makecache
    yum list --showduplicates postgresql11

    yum install -y postgresql11-server-11.2-2PGDG.rhel7.x86_64 postgresql11-contrib-11.2-2PGDG.rhel7.x86_64
    yum install -y keepalived

## 3 Create PostgreSQL server on pgsql1

### 3.1 Create PGDATA directory and run `initdb`

    mkdir -p /u01/pgdata/11
    chown -R postgres.postgres /u01/pgdata
    chmod 700 /u01/pgdata/11
    su - postgres
    echo 'postgres_password' > /u01/pgdata/.super_password
    /usr/pgsql-11/bin/initdb --pgdata=/u01/pgdata/11 --encoding=UTF8 --locale=C --username=postgres --pwfile=/u01/pgdata/.super_password
    mkdir /u01/pgdata/11/pg_archive

### 3.2 Setting some aliases for PostgreSQL server management

    cat << EOF >> ~/.bash_profile
    alias start_pgsql11='/usr/pgsql-11/bin/pg_ctl -D /u01/pgdata/11 -l /u01/pgdata/11/postgresql.log start'
    alias stop_pgsql11='/usr/pgsql-11/bin/pg_ctl -D /u01/pgdata/11 -l /u01/pgdata/11/postgresql.log stop -m fast'
    alias restart_pgsql11='/usr/pgsql-11/bin/pg_ctl -D /u01/pgdata/11 -l /u01/pgdata/11/postgresql.log restart'
    alias reload_pgsql11='/usr/pgsql-11/bin/pg_ctl -D /u01/pgdata/11 -l /u01/pgdata/11/postgresql.log reload'
    EOF
    source ~/.bash_profile

### 3.3 Adjusting parameter of PostgreSQL server

You can modify your `postgresql.conf` file if you need, for example:

    listen_addresses = '*'                  # what IP address(es) to listen on;
    port = 5432                             # (change requires restart)
    max_connections = 500                   # (change requires restart)
    shared_buffers = 1024MB                 # min 512kB
    max_wal_size = 2GB
    min_wal_size = 1024MB
    effective_cache_size = 4GB
    log_destination = 'stderr'              # Valid values are combinations of
    logging_collector = on                  # Enable capturing of stderr and csvlog
    log_directory = 'log'                   # directory where log files are written,
    log_filename = 'postgresql-%a.log'      # log file name pattern,
    log_truncate_on_rotation = on           # If on, an existing log file with the
    log_rotation_age = 1d                   # Automatic rotation of logfiles will
    log_rotation_size = 0                   # Automatic rotation of logfiles will
    log_line_prefix = '%m [%p] '            # special values:
    log_timezone = 'Asia/Shanghai'
    datestyle = 'iso, mdy'
    timezone = 'Asia/Shanghai'
    lc_messages = 'C'                       # locale for system error message
    lc_monetary = 'C'                       # locale for monetary formatting
    lc_numeric = 'C'                        # locale for number formatting
    lc_time = 'C'                           # locale for time formatting
    default_text_search_config = 'pg_catalog.english'
    archive_mode = on               # enables archiving; on, on, or always
    archive_command = 'test ! -f /u01/pgdata/11/pg_archive/%f && cp %p /u01/pgdata/11/pg_archive/%f'

Add the following line to `pg_hba.conf`:

    echo "host    all    all    0.0.0.0/0    md5" >> /u01/pgdata/11/pg_hba.conf

### 3.4 Start PostgreSQL server on pgsql1 node

    start_pgsql11

### 3.5 Create `pg_stat_statements` extension view

    psql -U postgres -c 'create extension pg_stat_statements;'
    psql -U postgres -d template1 -c 'create extension pg_stat_statements;'
    echo "shared_preload_libraries = 'pg_stat_statements'" >> $PGCONF

## 4 Setup Stream Replication

### 4.1 On node pgsql1

Create replication user and replication slot:

    su - postgres
    psql -U postgres -d postgres
    CREATE USER replman REPLICATION LOGIN CONNECTION LIMIT 5 ENCRYPTED PASSWORD 'replman';
    SELECT * FROM pg_create_physical_replication_slot('pg_replslot_001');
    select slot_name,plugin,slot_type,temporary,active from pg_replication_slots;
    \q

Modify `pg_hba.conf`:

    echo "host    replication    replman    172.16.0.0/24    md5" >> $PGHBA

Reload PostgreSQL server to take effect:

    reload_pgsql11

### 4.2 On node pgsql2

Get the base full backup from pgsql1 node:

    su - postgres
    mkdir /u01/pgdata/11
    chown -R postgres.postgres /u01/pgdata
    chmod 700 /u01/pgdata/11
    pg_basebackup -D /u01/pgdata/11 -U replman -h pgsql1-priv -p 5432 -X stream -F p -c fast -W -R -v

    cat <<EOF >> ./recovery.conf
    recovery_target_timeline = 'latest'
    #trigger_file = '/tmp/.TRIGGER.PGSQL.5432'
    primary_slot_name = 'pg_replslot_001'
    EOF
    ~/scripts/postgresql_start.sh

Optionally, you can create replication slot here:

    psql -U postgres -c "SELECT * FROM pg_create_physical_replication_slot('pg_replslot_001');"
    psql -U postgres -c "select slot_name,plugin,slot_type,temporary,active from pg_replication_slots;"

### 4.3 Check stream replication status

Check replication status from pgsql1 node:

    pg_controldata -D $PGDATA |grep  cluster
    psql -U postgres -x -c "select * from pg_stat_replication;"
    psql -U postgres -c "select slot_name,plugin,slot_type,temporary,active from pg_replication_slots;"

## 5 Create database `pgmonitor` for keepalived to monitoring replication status

You must run the following command in pgsql1 node(Master) only:

    su - postgres
    psql -U postgres
    create role pgmonitor superuser nocreatedb nocreaterole noinherit login encrypted password 'pgmonitor';
    create database pgmonitor with template template0 encoding 'UTF8' owner pgmonitor;
    \c pgmonitor pgmonitor
    create schema pgmonitor;
    create table cluster_status (id int unique default 1, last_alive timestamp(0) without time zone);
    
    CREATE FUNCTION cannt_delete ()
        RETURNS trigger
        LANGUAGE plpgsql AS $$
        BEGIN
        RAISE EXCEPTION 'You can not delete!';
        END; $$;
        
    CREATE TRIGGER cannt_delete BEFORE DELETE ON cluster_status FOR EACH ROW EXECUTE PROCEDURE cannt_delete();
    CREATE TRIGGER cannt_truncate BEFORE TRUNCATE ON cluster_status FOR STATEMENT EXECUTE PROCEDURE cannt_delete();
    
    insert into cluster_status values (1, now());
    \q

Add the following lines to `pg_hba.conf` to allow `pgmonitor` user to connect:

    host    pgmonitor      pgmonitor  127.0.0.1/32      md5
    host    pgmonitor      pgmonitor  10.128.0.11/32    md5
    host    pgmonitor      pgmonitor  10.128.0.12/32    md5
    host    pgmonitor      pgmonitor  10.128.0.10/32    md5

Then, reload PostgreSQL server(Master): 

    reload_pgsql11

## 6 Configure keepalived on both nodes

Clone this repository to your server, put `scripts` directory into `/root/`. Setting the excute permission(700) for all scripts like this:

    chmod 700 /root/scripts/*.sh
    chmod 700 /root/scripts/keepalived/*.sh

> **Note:** You must install package `psmisc` in your server to use `keepalived_stop.sh` scripts.

put `keepalived.conf-master` to master server(/etc/keepalived/keepalived.conf), and `keepalived.conf-salve` to standby server(/etc/keepalived/keepalived.conf).

Create log file directory `/var/log/keepalived` to store the keepalived log:

    mkdir -p /var/log/keepalived

Configure rsyslog service to not record keepalived log information in system message file `/var/log/messages`:

    cat << EOF >> /etc/rsyslog.conf
    # Keepalived log setting:
    local1.*    /var/log/keepalived/keepalived.log
    EOF
    systemctl restart rsyslog.service
    systemctl disable keepalived.service

## Start keepalived daemon

### Start keepalived daemon on master server

    /root/scripts/keepalived_start.sh

> **Note:** You must start the keepalived daemon on master server first.

### Start keepalived daemon on standby server

When keepalived daemon is running OK on master server, then start it on standby node:  

    /root/scripts/keepalived_start.sh



