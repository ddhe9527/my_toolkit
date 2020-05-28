## mycnf_helper

#### mycnf_helper主要有如下两个功能：

1. 针对特定的服务器配置(CPU、内存、IOPS能力、是否使用SSD等)，生成适用于特定MySQL版本的my.cnf文件
2. 在当前服务器上安装MySQL Server，并部署主从或双主复制

上述两个功能可以单独使用，也可以一起使用。例如：可以先生成my.cnf文件后，人工检查确认，再使用-s参数安装部署。也可以跳过人工复核过程，直接生成并部署

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
- -S：使用了SSD存储，影响innodb_flush_neighbors参数和IO Scheduler检查逻辑
- -t：安装辅助工具，包括XtraBackup工具等
- -v：指定要安装的MySQL Server版本号
- -x：指定主从或双主复制场景中，对端节点的IP地址。该IP将使用在当前节点执行的"CHANGE MASTER TO"命令中
- -y：指定双主复制场景中，自己的IP地址。该IP将使用在对端节点执行的"CHANGE MASTER TO"命令中
- -z：设置MySQL Server随操作系统自动启动

#### 注意事项：

- 必须确保yum源可用，否则安装过程会报错
- 脚本会自动读取当前目录下与“-v”选项指定的版本号所对应的MySQL二进制包进行安装。例如：-v选项指定5.7.22，那么脚本会尝试在当前路径中查找类似"mysql-5.7.22-linux-glibc2.12-x86_64.tar.gz"的文件用于后续安装
- 如果要安装辅助工具，例如XtraBackup，则相关依赖rpm包也必须存放在当前路径下
- 成功安装后，会自动删除数据库中的匿名账号和test数据库，'root'@'localhost'账号将被保留
- 成功安装后，会自动创建具有SUPER和REPLICATION SLAVE权限的'repl'@'%'，用于搭建复制
- -v为强制选项，必须显式指定

#### 使用范畴：

- 支持64位CentOS/Red Hat 5.x, 6.x, 7.x, 8.x操作系统下执行安装部署
- 支持MySQL 5.6.10及以上版本的安装部署

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

