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
- -i：指定server_id，默认值为1
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

