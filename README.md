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









