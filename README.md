# pgsql11-ha-with-keepalived
PostgreSQL 11.2高可用集群：Stream Replication + Keepalived HA

## 环境

两台服务器：

- pgsql1  eth1:10.128.0.11/24（eth2:172.16.0.11/24，复制网络） CentOS7.6
- pgsql2  eth1:10.128.0.12/24（eth2:172.16.0.12/24，复制网络） CentOS7.6
- Virtual IP: 10.128.0.10/24

软件版本：

- PostgreSQL：
- Keepalived：


