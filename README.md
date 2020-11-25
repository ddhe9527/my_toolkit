这是一个自用的DBA工具集，当前已包括mycnf_helper、redis_helper，后续将逐步增加更多脚本

Email：heduoduo321@163.com



## mycnf_helper

#### mycnf_helper主要有如下两个功能：

1. 针对特定的服务器配置(CPU、内存、IOPS能力、是否使用SSD等)，生成适用于特定MySQL版本的最佳实践my.cnf文件
2. 在当前服务器上安装MySQL Server，并部署主从或双主复制

上述两个功能可以单独使用，也可以一起使用。例如：可以先生成my.cnf文件后，人工检查确认，再使用-s参数安装部署；也可以跳过人工复核过程，直接生成my.cnf并部署数据库实例。另外，mycnf_helper脚本逻辑已尽量做到幂等，如果中途执行报错，则清理中间文件或目录后，重复执行即可

#### 选项说明：

- -a：自动获取当前服务器的CPU核数和内存容量信息
- -b：指定安装MySQL的basedir，默认值为/usr/local/mysql
- -c：指定CPU核数
- -d：指定安装MySQL的datadir的上层目录，默认值为/mysql_data
- -f：指定安装MySQL时要使用的my.cnf文件
- -h：打印帮助信息
- -i：指定server_id，默认值为0~32767之间的随机数
- -I：指定IOPS能力，默认值4000
- -m：指定内存容量大小，单位GB，并且不能小于1GB
- -M：开启双主复制，并指定auto_increment_offset参数值，该值必须为1或2
- -n：如果要部署NTP时间同步，可使用该参数指定NTP server的IP地址
- -o：指定要生成的my.cnf文件名及其路径信息，默认值为$PWD/my.cnf，即当前路径下
- -p：指定MySQL端口号，默认值为3306
- -r：指定主从复制中的角色，该值必须为master或slave。如果不存在复制关系，则指定master即可
- -s：在当前服务器上安装部署MySQL Server
- -S：使用了SSD存储，影响innodb_flush_neighbors参数和I/O Scheduler检查逻辑
- -t：安装辅助工具，包括XtraBackup工具等
- -v：指定要安装的MySQL Server版本号
- -x：指定主从或双主复制场景中，对端节点的IP地址。该IP将使用在当前节点执行的"CHANGE MASTER TO"命令中
- -y：指定双主复制场景中，自己的IP地址。该IP将使用在对端节点执行的"CHANGE MASTER TO"命令中
- -z：设置MySQL Server随操作系统自动启动

#### 注意事项：

- 必须确保yum源可用，否则安装过程会报错
- 安装过程中会修改Linux内核参数、调整mysql用户资源限制、关闭SELinux和防火墙等
- 脚本会自动读取当前目录下与“-v”选项指定的版本号所对应的MySQL二进制包进行安装。例如：-v选项指定5.7.22，那么脚本会尝试在当前路径中查找类似"mysql-5.7.22-linux-glibc2.12-x86_64.tar.gz"的文件用于后续安装
- 如果要安装辅助工具，例如XtraBackup，则相关依赖rpm包也必须存放在当前路径下
- 成功安装后，会自动删除数据库中的匿名账号和test数据库
- 成功安装后，会自动创建具有SUPER和REPLICATION SLAVE权限的'repl'@'%'，用于搭建复制
- -v为强制选项，必须显式指定

#### 使用范畴：

- 操作系统：CentOS/Red Hat 5.X ~ 8.X x86_64
- MySQL：5.6.10及以上版本

#### 使用范例：

范例一：为8core、16GB、IOPS=5000的Server创建适用于MySQL 5.7.22的my.cnf配置文件：

```
./mycnf_helper.sh -c 8 -m 16 -I 5000 -v 5.7.22 -r master -o /root/my.cnf
```

范例二：利用“范例一”生成的my.cnf文件，安装部署MySQL 5.7.22，并设置开机自启动

```
./mycnf_helper.sh -v 5.7.22 -f /root/my.cnf -s -z
```

范例三：在两台服务器上搭建主从：

- 服务器A：192.168.90.135，使用SSD存储，IOPS=20000
- 服务器B：192.168.90.136，使用SSD存储，IOPS=20000
- 数据库版本为MySQL 8.0.18
- 服务器A上运行主库(server_id=1)，服务器B上运行从库(server_id=2)
- 网络环境中存在一台NTP服务器(192.168.90.100)，可为二者提供NTP服务
- 安装XtraBackup工具

```
服务器A：./mycnf_helper.sh -a -I 20000 -v 8.0.18 -S -s -n 192.168.90.100 -r master -i 1 -t
服务器B：./mycnf_helper.sh -a -I 20000 -v 8.0.18 -S -s -n 192.168.90.100 -r slave -i 2 -x 192.168.90.135 -t
```

范例四：“范例三”中两台同等配置的服务器，如果搭建成双主，则采用如下命令：

```
服务器A：./mycnf_helper.sh -a -I 20000 -v 8.0.18 -S -s -n 192.168.90.100 -r master -i 1 -t -M 1
服务器B：./mycnf_helper.sh -a -I 20000 -v 8.0.18 -S -s -n 192.168.90.100 -r master -i 2 -t -M 2 -x 192.168.90.135 -y 192.168.90.136
```

#### 附录：

“范例一”生成的my.cnf文件内容：

```
[mysqld]
user = mysql
port = 3306
server_id = 1
basedir = /usr/local/mysql
datadir = /mysql_data/data
tmpdir = /mysql_data/tmp
socket = /mysql_data/mysql.sock
loose-mysqlx_socket = /mysql_data/mysqlx.sock
pid_file = /mysql_data/mysql.pid
autocommit = ON
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci
transaction_isolation = READ-COMMITTED
lower_case_table_names = 1
sync_binlog = 1
secure_file_priv = /mysql_data/tmp
log_bin = /mysql_data/binlog/bin.log
binlog_format = ROW
expire_logs_days = 15
binlog_rows_query_log_events = ON
log_bin_trust_function_creators = ON
log_error = /mysql_data/error.log
slow_query_log = ON
slow_query_log_file = /mysql_data/slowlog/slow.log
log_queries_not_using_indexes = ON
log_throttle_queries_not_using_indexes = 10
long_query_time = 2
log_slow_admin_statements = ON
log_slow_slave_statements = ON
min_examined_row_limit = 100
log_timestamps = SYSTEM
sql_mode = NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,ONLY_FULL_GROUP_BY
table_open_cache_instances = 16
max_connections = 800
max_allowed_packet = 256M
join_buffer_size = 2M
read_buffer_size = 2M
binlog_cache_size = 2M
read_rnd_buffer_size = 2M
key_buffer_size = 16M
tmp_table_size = 32M
max_heap_table_size = 32M
interactive_timeout = 7200
wait_timeout = 7200
max_connect_errors = 1000000
lock_wait_timeout = 3600
thread_cache_size = 64
myisam_sort_buffer_size = 32M
binlog_error_action = ABORT_SERVER
default_authentication_plugin = mysql_native_password
innodb_file_per_table = ON
innodb_file_format = Barracuda
innodb_file_format_max = Barracuda
innodb_large_prefix = ON
innodb_flush_log_at_trx_commit = 1
innodb_stats_persistent_sample_pages = 128
innodb_buffer_pool_size = 11400M
innodb_buffer_pool_instances = 8
innodb_read_io_threads = 16
innodb_write_io_threads = 8
innodb_purge_threads = 4
innodb_page_cleaners = 8
innodb_flush_neighbors = 1
innodb_io_capacity = 2500
innodb_flush_method = O_DIRECT
innodb_log_file_size = 2048M
innodb_log_group_home_dir = /mysql_data/redolog
innodb_log_files_in_group = 4
innodb_log_buffer_size = 32M
innodb_undo_directory = /mysql_data/undolog
innodb_undo_tablespaces = 3
innodb_undo_log_truncate = ON
innodb_max_undo_log_size = 4G
innodb_checksum_algorithm = crc32
innodb_thread_concurrency = 8
innodb_lock_wait_timeout = 10
innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:96G
innodb_print_all_deadlocks = ON
innodb_strict_mode = ON
innodb_autoinc_lock_mode = 2
innodb_online_alter_log_max_size = 2G
innodb_sort_buffer_size = 2M
innodb_rollback_on_timeout = ON
skip_name_resolve = ON
performance_schema_instrument = "wait/lock/metadata/sql/mdl=ON"
event_scheduler = ON
read_only = OFF
super_read_only = OFF
log_slave_updates = ON
gtid_mode = ON
enforce_gtid_consistency = ON
relay_log = /mysql_data/relaylog/relay.log
master_info_repository = TABLE
relay_log_info_repository = TABLE
relay_log_recovery = ON
skip_slave_start = ON
plugin_load = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"
rpl_semi_sync_master_enabled = ON
rpl_semi_sync_slave_enabled = ON
rpl_semi_sync_master_timeout = 5000
```


## redis_helper

#### redis_helper主要有如下两个功能：

1. 生成适用于特定Redis版本的配置文件，支持对RDB持久化、AOF持久化、port、dir、maxmemory、requirepass、replicaof等配置进行自定义，支持Redis Cluster、Sentinel部署模式。当前已适配了Redis 3.0.0~6.0.9版本，后续版本如果有新增或删减参数，将持续更新到代码中
2. 在功能1的基础上，直接在当前服务器上编译安装Redis程序，并启动运行。安装过程中会根据Redis运行需求对操作系统内核参数、SELinux、防火墙、透明大页和用户limits等进行配置

#### 选项说明：

- -A：打开AOF持久化，默认处于关闭状态
- -c：开启集群模式，默认处于关闭状态
- -C：当实例以集群模式并启动运行后，指定与哪个cluster node进行MEET，即加入现有集群。此外还可以指定自己成为该cluster node的replica。格式为：IP:PORT:ROLE，其中ROLE只能是'master'或'replica'
- -d：指定dir参数。默认值为./(sentinel默认值为/tmp)
- -f：如果已经有现成的redis配置文件，则使用-f选项指定该文件安装启动运行实例
- -h：打印帮助信息并退出
- -m：指定maxmemory参数，默认值为1024mb，如果当前服务器的总内存小于1224mb，则默认值为"总内存 - 200mb"。注意maxmemory不能大于"物理总内存-200mb"
- -M：指定sentinel monitor参数，格式为：MASTER_NAME:IP:PORT:QUORUM
- -n：指定NTP服务器的IP地址，默认不配置NTP
- -o：指定要生成的配置文件的路径和名称，仅支持绝对路径，默认为当前目录下的redis.conf或sentinel.conf
- -p：指定port参数，默认值为6379(sentinel默认为26379)
- -P：指定requirepass参数，默认没有密码
- -r：指定replicaof参数，格式为：IP:PORT
- -R：开启RDB持久化，默认处于关闭状态
- -s：sentinel模式
- -S：安装部署Redis二进制程序，默认仅生成配置文件，不安装
- -u：指定以某个操作系统用户身份来启动运行redis实例，该用户必须已存在，并且具有必要的权限
- -v：指定redis版本信息
- -x：在主从复制场景中，如果master设置了密码，则用该选项为replica设置masterauth参数，或为sentinel设置auth-pass

#### 注意事项：

- 必须确保yum源可用，否则安装过程会报错
- 安装过程中会修改Linux内核参数、调整用户资源限制、关闭SELinux和防火墙等
- 脚本会自动读取当前目录下与“-v”选项指定的版本号所对应的Redis二进制包进行安装。例如：-v选项指定3.0.0，那么脚本会尝试在当前路径中查找类似"redis-3.0.0.zip"或"redis-3.0.0.tar.gz"的文件用于后续安装
- -v为强制选项，必须显式指定
- 当使用-s选项部署sentinel时，-M选项是强制选项，必须显式指定
- 当使用-c和-C选项部署Redis Cluster时，脚本仅支持到"CLUSTER MEET"和"CLUSTER REPLICATE"步骤，即仅支持到加入集群和建立复制关系(可选)步骤，后续的SLOT迁移和分配则必须手动来完成

#### 使用范畴：

- 操作系统：CentOS/Red Hat 5.X ~ 8.X x86_64
- Redis版本：3.0.0及以上版本。已测试的版本为3.0.0~6.0.9

#### 使用范例：

范例一：生成适用于6.0.3版本redis的配置文件/var/redis/6380.conf，集群模式，占用内存上限为2GB，端口号为6380，dir为/var/redis/6380，开启RDB和AOF持久化：

```
./redis_helper.sh -v 6.0.3 -c -m 2048mb -p 6380 -d /var/redis/6380/ -o /var/redis/6380.conf -A -R
```

范例二：使用"范例一"创建的/var/redis/6380.conf，安装部署redis实例并启动，同时配置NTP时间同步，NTP Server为192.168.0.101。启动实例后，与192.168.0.50:6379实例进行meet，并成为该实例的replica

```
./redis_helper.sh -v 6.0.3 -f /var/redis/6380.conf -n 192.168.0.101 -C 192.168.0.50:6379:replica -S
```

范例三：等价于"范例一"和"范例二"的组合

```
./redis_helper.sh -v 6.0.3 -c -m 2048mb -p 6380 -d /var/redis/6380/ -o /var/redis/6380.conf -A -R -n 192.168.0.101 -C 192.168.0.50:6379:replica -S
```

#### 附录：

“范例一”生成的/var/redis/6380.conf 文件内容：

```
# include
# loadmodule
bind 0.0.0.0
protected-mode yes
port 6380
tcp-backlog 511
# unixsocket
# unixsocketperm
timeout 0
tcp-keepalive 60
# tls-port
# tls-cert-file
# tls-key-file
# tls-dh-params-file
# tls-ca-cert-file
# tls-ca-cert-dir
# tls-auth-clients
# tls-replication
# tls-cluster
# tls-protocols
# tls-ciphers
# tls-ciphersuites
# tls-prefer-server-ciphers
daemonize yes
supervised no
pidfile /var/redis/6380/redis_6380.pid
loglevel notice
logfile /var/redis/6380/redis_6380.log
# syslog-enabled
# syslog-ident
# syslog-facility
databases 16
always-show-logo yes
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump_6380.rdb
rdb-del-sync-files no
dir /var/redis/6380/
# replicaof
# masterauth
# masteruser
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-diskless-load disabled
# repl-ping-replica-period
repl-timeout 60
repl-disable-tcp-nodelay no
repl-backlog-size 20mb
repl-backlog-ttl 7200
replica-priority 100
# min-replicas-to-write
# min-replicas-max-lag
# replica-announce-ip
# replica-announce-port
# tracking-table-max-keys
# user
acllog-max-len 128
# aclfile
# requirepass
# rename-command
maxclients 10000
maxmemory 2048mb
maxmemory-policy volatile-ttl
# maxmemory-samples
# replica-ignore-maxmemory
# active-expire-effort
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
replica-lazy-flush yes
lazyfree-lazy-user-del yes
# io-threads
# io-threads-do-reads
appendonly yes
appendfilename appendonly_6380.aof
appendfsync everysec
no-appendfsync-on-rewrite yes
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
lua-time-limit 5000
cluster-enabled yes
cluster-config-file cluster_node_6380.conf
cluster-node-timeout 15000
cluster-replica-validity-factor 10
cluster-migration-barrier 1
cluster-require-full-coverage no
# cluster-replica-no-failover
cluster-allow-reads-when-down yes
# cluster-announce-ip
# cluster-announce-port
# cluster-announce-bus-port
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
# gopher-enabled
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 512mb 128mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
# client-query-buffer-limit
# proto-max-bulk-len
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
# lfu-log-factor
# lfu-decay-time
activedefrag yes
# active-defrag-ignore-bytes
# active-defrag-threshold-lower
# active-defrag-threshold-upper
# active-defrag-cycle-min
# active-defrag-cycle-max
# active-defrag-max-scan-fields
jemalloc-bg-thread yes
# server_cpulist
# bio_cpulist
# aof_rewrite_cpulist
# bgsave_cpulist
```