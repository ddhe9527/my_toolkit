#!/bin/sh

## Default values
MY_CNF=$PWD/my.cnf
DATA_DIR=/mysql_data
BASE_DIR=/usr/local/mysql
TMP_FILE=/tmp/mycnf_helper.log
MY_PORT=3306
IO_CAP=4000
OLDEST_MYSQL_VERSION=50609
SERVER_ID=$RANDOM               ##random number between 0 and 32767
ROOT_PASSWD=Mycnf_helper123!    ##password for 'root'@'localhost' with ALL privilege
REPL_PASSWD=Mycnf_helper456!    ##password for 'repl'@'%' with REPLICATION SLAVE and SUPER privilege
WAIT_TIME=30                    ##Sleep time(second) before checking the mysqld process

## Flags(internal use)
SETUP_FLAG=0
SSD_FLAG=0
SKIP_GENERATE_MYCNF=0
DATADIR_NOT_EMPTY_FLAG=0
BASEDIR_NOT_EMPTY_FLAG=0
MM_FLAG=0
NTP_FLAG=0
AUTOSTART_FLAG=0
SUPER_RO=0
MASTER_IP_FLAG=0
OWN_IP_FLAG=0
FAIL_FLAG=0
INSTALL_TOOLS_FLAG=0

## -h option
function usage()
{
echo 'mycnf_helper has two main functions:
1): generate a best-practice my.cnf for specific MySQL version(default behavior)
2): install MySQL Server(with -s option)
=====================================================================================================
Usage:
-a:          automatically gets CPU core count and memory capacity from current server
-b: <string> MySQL Server base directory(default: /usr/local/mysql)
-c: <number> logical CPU core count
-d: <string> MySQL initial data directory(default: /mysql_data)
-f: <string> specify a my.cnf for MySQL Server setup(this file should have mycnf_helper fingerprint)
-h:          print help information
-i: <number> server_id(default: random number between 0 and 32767)
-I: <number> IO capacity(IOPS) of the storage(default: 4000)
-m: <number> memory capacity(unit: GB)
-M: <number> use master-master replication and specify auto_increment_offset(1 or 2)
-n: <string> NTP server IP address
-o: <string> destination of MySQL config file(default: $PWD/my.cnf)
-p: <number> port(default: 3306)
-r: <string> replication role, must be master or slave
-s:          generate a my.cnf file and setup the MySQL Server
-S:          use SSD storage(for innodb_flush_neighbors)
-t:          install tools: XtraBackup etc.
-v: <string> MySQL Server version. eg: 5.6.32, 5.7.22, 8.0.1
-x: <string> replication master IP address that will be used in "CHANGE MASTER TO" statement
-y: <string> own IP address that will be used in reversed "CHANGE MASTER TO" statement to
             build master-master topology
-z:          make mysqld autostart with the operation system
=====================================================================================================
Theoretically supported platforms(x86_64):
    * Red Hat 5.x ~ 8.x
    * CentOS  5.x ~ 8.x
Currently known successfully tested platforms(x86_64):
    * Red Hat 5.8, 6.8
    * CentOS  7.7, 8.1

Theoretically supported MySQL versions:
    * 5.6.9 and above
Currently known successfully tested MySQL versions:
    * 5.6.10
    * 5.6.37
    * 5.7.25
    * 5.7.29
    * 8.0.18

Example:
1): Generate a my.cnf for MySQL 5.6.10 that will be running on particular server with following features:
    * server configuration: 4core, 8GB, SSD storage(IOPS=20000)
    * basedir=/usr/local/mysql5.6
    * datadir=/my_data
    * port=3307
    * server_id=5

    This command will generate a my.cnf in current directory:
    ./mycnf_helper.sh -c 4 -m 8 -I 20000 -v 5.6.10 -b /usr/local/mysql5.6 -d /my_data -p 3307 -i 5 -S -r master

2): Setup MySQL 5.6.10 using specified my.cnf. Make sure the my.cnf exists and one corresponding MySQL binary
    tar.gz or tar.xz package in current directory, such as mysql-5.6.10-linux-glibc2.5-x86_64.tar.gz etc.

    This command is suitable for this situation:
    ./mycnf_helper.sh -v 5.6.10 -f /root/my.cnf -s

3): Setup a one-way replication with following features:
    * two servers with same hardware configuration: 8core, 16GB, SSD storage(IOPS=10000)
    * MySQL version: 8.0.18
    * master IP address: 192.168.90.135
    * master server_id: 10
    * slave IP address: 192.168.90.136
    * slave server_id: 20
    * datadir=/mysql_data (default)
    * basedir=/usr/local/mysql (default)
    * port=3306 (default)
    * has a NTP server: 192.168.90.100

    These commands will automatically generate a my.cnf and setup MySQL 8.0.18:
    * master: ./mycnf_helper.sh -a -I 10000 -v 8.0.18 -S -s -n 192.168.90.100 -r master -i 10
    * slave : ./mycnf_helper.sh -a -I 10000 -v 8.0.18 -S -s -n 192.168.90.100 -r slave -i 20 -x 192.168.90.135

4): Similar to example 3, if setup a master-master replication with features like above, use these commands:
    * master1: ./mycnf_helper.sh -a -I 10000 -v 8.0.18 -S -s -n 192.168.90.100 -r master -i 10 -M 1
    * master2: ./mycnf_helper.sh -a -I 10000 -v 8.0.18 -S -s -n 192.168.90.100 -r master -i 20 -M 2 -x 192.168.90.135 -y 192.168.90.136


Github: https://github.com/ddhe9527/my_toolkit
Email : heduoduo321@163.com

Enjoy and free to use at your own risk~'
}

## Print error message with red color font, then quit with code 1
function error_quit(){
    echo `tput setaf 1; tput bold`"Error: "$1`tput sgr0`
    exit 1
}

## Phase options
while getopts "ab:c:d:f:hi:I:m:M:n:o:p:r:sStv:x:y:z" opt
do
    case $opt in
        a)
            CPU_CORE_COUNT=`cat /proc/cpuinfo | grep -c processor`
            MEM_CAP=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
            let MEM_CAP=$MEM_CAP/1024/1024;;
        b)
            BASE_DIR=$OPTARG;;
        c)
            CPU_CORE_COUNT=$OPTARG;;
        d)
            DATA_DIR=$OPTARG;;
        f)
            F_FILE=$OPTARG
            SKIP_GENERATE_MYCNF=1;;
        h)
            usage
            exit 0;;
        i)
            SERVER_ID=$OPTARG;;
        I)
            IO_CAP=$OPTARG;;
        m)
            MEM_CAP=$OPTARG;;
        M)
            MM_FLAG=1
            AUTO_INCREMENT_OFFSET=$OPTARG;;
        n)
            NTP_FLAG=1
            NTP_SERVER=$OPTARG;;
        o)
            MY_CNF=$OPTARG;;
        p)
            MY_PORT=$OPTARG;;
        r)
            REPL_ROLE=$OPTARG;;
        s)
            SETUP_FLAG=1;;
        S)
            SSD_FLAG=1;;
        t)
            INSTALL_TOOLS_FLAG=1;;
        v)
            SERVER_VERSION=$OPTARG;;
        x)
            MASTER_IP_FLAG=1
            MASTER_IP=$OPTARG;;
        y)
            OWN_IP_FLAG=1
            OWN_IP=$OPTARG;;
        z)
            AUTOSTART_FLAG=1;;
        *)
            error_quit "Unknown option, try -h for more information";;
    esac
done


if [[ $SKIP_GENERATE_MYCNF -eq 1 && $SETUP_FLAG -eq 0 ]]
then
    echo "Nothing needs to be done"
    exit 0
fi


if [ $SKIP_GENERATE_MYCNF -eq 0 ]
then
    ## Make sure the CPU core count is digit
    if [ `echo $CPU_CORE_COUNT | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "CPU core count: $CPU_CORE_COUNT cores"
    else
        error_quit "Invalid CPU core count, use -c to specify, or use -a to get from /proc/cpuinfo"
    fi

    ## Make sure the memory capacity is digit
    if [ `echo $MEM_CAP | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "Memory capacity: $MEM_CAP""GB"
    else
        error_quit "Invalid memory capacity(less than 1GB), use -m to specify, or use -a to get from /proc/meminfo"
    fi

    ## Make sure the port is digit
    if [ `echo $MY_PORT | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "MySQL Server port: $MY_PORT"
    else
        error_quit "Invalid port number, use -p to specify"
    fi

    ## Make sure the server_id is digit
    if [ `echo $SERVER_ID | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "MySQL Server server_id: $SERVER_ID"
    else
        error_quit "Invalid server_id, use -i to specify"
    fi

    ## Make sure the IOPS is digit
    if [ `echo $IO_CAP | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "IO capacity: $IO_CAP IOPS"
    else
        error_quit "Invalid IO capacity, use -I to specify"
    fi

    ## Check the destination of my.cnf
    if [ ${MY_CNF:0:1} != '/' ]
    then
        error_quit 'Please use absolute path for my.cnf file'
    fi

    if [ -f $MY_CNF ]
    then
        error_quit "$MY_CNF has already exists, overwriting is not supported because of safety, try -o option to specify a different file name or renaming the existing one"
    else
        MY_DIR=${MY_CNF%/*}
        if [ ! -d $MY_DIR ]
        then
            error_quit "$MY_DIR does not exists"
        else
            ##touch $MY_CNF
            echo "MySQL config file will be created: $MY_CNF"
        fi
    fi

    ## Check the data directory, must be empty or not exist
    DATA_DIR=${DATA_DIR%*/}
    if [ ${DATA_DIR:0:1} != '/' ]
    then
        error_quit "Please use absolute path for datadir"
    fi

    echo "MySQL data directory: "$DATA_DIR
    if [ -d $DATA_DIR ]
    then
        if [ `find $DATA_DIR -maxdepth 1 | wc -l` -gt 1 ]
        then
            echo `tput bold`"Be carefull, $DATA_DIR is not empty"`tput sgr0`
            DATADIR_NOT_EMPTY_FLAG=1
        fi
    fi

    ## Check the base directory, must be empty or not exist
    BASE_DIR=${BASE_DIR%*/}
    if [ ${BASE_DIR:0:1} != '/' ]
    then
        error_quit "Please use absolute path for basedir"
    fi

    echo "MySQL base directory: "$BASE_DIR
    if [ -d $BASE_DIR ]
    then
        if [ `find $BASE_DIR -maxdepth 1 | wc -l` -gt 1 ]
        then
            echo `tput bold`"Be carefull, $BASE_DIR is not empty"`tput sgr0`
            BASEDIR_NOT_EMPTY_FLAG=1
        fi
    fi

    ## Check AUTO_INCREMENT_OFFSET
    if [ $MM_FLAG -eq 1 ]
    then
        if [[ $AUTO_INCREMENT_OFFSET -eq 1 || $AUTO_INCREMENT_OFFSET -eq 2 ]]
        then
            echo "Master-Master replication is enabled, auto_increment_offset = $AUTO_INCREMENT_OFFSET"
            REPL_ROLE=M
        else
            error_quit "Invalid auto_increment_offset, use -M to specify(1 or 2)"
        fi
    fi
else
    if [ -f $F_FILE ]
    then
        if [ `cat $F_FILE | grep -c mycnf_helper_fingerprint` -ne 2 ]
        then
            error_quit "$F_FILE does not has mycnf_helper fingerprint"
        else
            echo "$F_FILE will be used to setup the MySQL Server"
        fi
    else
        error_quit "$F_FILE does not exists"
    fi
fi


## Check replication role
if [ `echo $REPL_ROLE | grep -ic slave` -eq 1 ]
then
    REPL_ROLE=S
    echo "Replication role: slave"
elif [ `echo $REPL_ROLE | grep -ic master` -eq 1 ]
then
    REPL_ROLE=M
    echo "Replication role: master"
else
    error_quit "Replication role must be master or slave, use -r to specify"
fi


## Check MySQL Server version
if [ `echo $SERVER_VERSION | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'` ]
then
    if [ `echo ${SERVER_VERSION##*.} | wc -L` -eq 1 ]
    then
        MYSQL_VERSION=`echo $SERVER_VERSION | sed "s/\./0/g"`
    else
        MYSQL_VERSION=`echo $SERVER_VERSION | sed "s/\.//2g" | sed "s/\./0/g"`
    fi

    if [ $MYSQL_VERSION -lt $OLDEST_MYSQL_VERSION ]
    then
        error_quit "MySQL Server version is too old to be supported"
    fi

    echo "MySQL Server version: $SERVER_VERSION($MYSQL_VERSION)"
else
    error_quit "Invalid MySQL Server version, use -v to specify"   
fi


## Generate the reference data
if [ $SKIP_GENERATE_MYCNF -eq 0 ]
then
    echo "@type:header@999999@0@this is a temporary file for mycnf_helper" > $TMP_FILE
    echo "@type:common@0@999999@user = mysql" >> $TMP_FILE
    echo "@type:common@0@999999@port = $MY_PORT" >> $TMP_FILE
    echo "@type:common@0@999999@server_id = $SERVER_ID" >> $TMP_FILE
    echo "@type:common@0@999999@basedir = $BASE_DIR" >> $TMP_FILE
    echo "@type:common@0@999999@datadir = $DATA_DIR/data" >> $TMP_FILE
    echo "@type:common@0@999999@tmpdir = $DATA_DIR/tmp" >> $TMP_FILE
    echo "@type:common@0@999999@socket = $DATA_DIR/mysql.sock" >> $TMP_FILE
    echo "@type:common@50715@999999@loose-mysqlx_socket = $DATA_DIR/mysqlx.sock" >> $TMP_FILE
    echo "@type:common@0@999999@pid_file = $DATA_DIR/mysql.pid" >> $TMP_FILE
    echo "@type:common@0@999999@autocommit = ON" >> $TMP_FILE
    echo "@type:common@0@999999@character_set_server = utf8mb4" >> $TMP_FILE
    echo "@type:common@0@999999@collation_server = utf8mb4_unicode_ci" >> $TMP_FILE
    echo "@type:common@0@999999@transaction_isolation = READ-COMMITTED" >> $TMP_FILE
    echo "@type:common@0@999999@lower_case_table_names = 1" >> $TMP_FILE
    echo "@type:common@0@999999@sync_binlog = 1" >> $TMP_FILE
    echo "@type:common@0@999999@report_host = "`hostname` >> $TMP_FILE
    echo "@type:common@0@999999@secure_file_priv = $DATA_DIR/tmp" >> $TMP_FILE
    echo "@type:common@0@999999@log_bin = $DATA_DIR/binlog/bin.log" >> $TMP_FILE
    echo "@type:common@0@999999@binlog_format = ROW" >> $TMP_FILE
    echo "@type:common@0@80000@expire_logs_days = 15" >> $TMP_FILE
    echo "@type:common@80001@999999@binlog_expire_logs_seconds = 1296000" >> $TMP_FILE
    echo "@type:common@50602@999999@binlog_rows_query_log_events = ON" >> $TMP_FILE
    echo "@type:common@0@999999@log_bin_trust_function_creators = ON" >> $TMP_FILE
    echo "@type:common@0@999999@log_error = $DATA_DIR/error.log" >> $TMP_FILE
    echo "@type:common@0@999999@slow_query_log = ON" >> $TMP_FILE
    echo "@type:common@0@999999@slow_query_log_file = $DATA_DIR/slowlog/slow.log" >> $TMP_FILE
    echo "@type:common@0@999999@log_queries_not_using_indexes = ON" >> $TMP_FILE
    echo "@type:common@50605@999999@log_throttle_queries_not_using_indexes = 10" >> $TMP_FILE
    echo "@type:common@0@999999@long_query_time = 2" >> $TMP_FILE
    echo "@type:common@50611@999999@log_slow_admin_statements = ON" >> $TMP_FILE
    echo "@type:common@50611@999999@log_slow_slave_statements = ON" >> $TMP_FILE
    echo "@type:common@0@999999@min_examined_row_limit = 100" >> $TMP_FILE
    echo "@type:common@50702@999999@log_timestamps = SYSTEM" >> $TMP_FILE
    echo "@type:common@0@50723@sql_mode = NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,ONLY_FULL_GROUP_BY" >> $TMP_FILE
    echo "@type:common@50724@999999@sql_mode = NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,ONLY_FULL_GROUP_BY" >> $TMP_FILE
    echo "@type:common@0@50703@metadata_locks_hash_instances = 256" >> $TMP_FILE
    echo "@type:common@50606@999999@table_open_cache_instances = 16" >> $TMP_FILE
    echo "@type:common@0@999999@max_connections = 800" >> $TMP_FILE
    echo "@type:common@0@999999@max_allowed_packet = 256M" >> $TMP_FILE
    echo "@type:common@0@999999@join_buffer_size = 2M" >> $TMP_FILE
    echo "@type:common@0@999999@read_buffer_size = 2M" >> $TMP_FILE
    echo "@type:common@0@999999@binlog_cache_size = 2M" >> $TMP_FILE
    echo "@type:common@0@999999@read_rnd_buffer_size = 2M" >> $TMP_FILE
    echo "@type:common@0@999999@key_buffer_size = 16M" >> $TMP_FILE
    echo "@type:common@0@999999@tmp_table_size = 32M" >> $TMP_FILE
    echo "@type:common@0@999999@max_heap_table_size = 32M" >> $TMP_FILE
    echo "@type:common@0@999999@interactive_timeout = 7200" >> $TMP_FILE
    echo "@type:common@0@999999@wait_timeout = 7200" >> $TMP_FILE
    echo "@type:common@0@999999@max_connect_errors = 1000000" >> $TMP_FILE
    echo "@type:common@0@999999@lock_wait_timeout = 3600" >> $TMP_FILE
    echo "@type:common@0@999999@thread_cache_size = 64" >> $TMP_FILE
    echo "@type:common@0@999999@myisam_sort_buffer_size = 32M" >> $TMP_FILE
    echo "@type:common@50622@50699@binlog_error_action = ABORT_SERVER" >> $TMP_FILE
    echo "@type:common@50706@999999@binlog_error_action = ABORT_SERVER" >> $TMP_FILE
    echo "@type:common@50702@999999@default_authentication_plugin = mysql_native_password" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_file_per_table = ON" >> $TMP_FILE
    echo "@type:common@0@50799@innodb_file_format = Barracuda" >> $TMP_FILE
    echo "@type:common@0@50799@innodb_file_format_max = Barracuda" >> $TMP_FILE
    echo "@type:common@50603@50799@innodb_large_prefix = ON" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_flush_log_at_trx_commit = 1" >> $TMP_FILE
    echo "@type:common@50602@999999@innodb_stats_persistent_sample_pages = 128" >> $TMP_FILE
    ##innodb_buffer_pool_size
    let BUFFER_POOL=$MEM_CAP*1024*7/10
    BPL=${#BUFFER_POOL}
    let BPL=$BPL-2
    echo "@type:common@0@999999@innodb_buffer_pool_size = ${BUFFER_POOL:0:$BPL}00M" >> $TMP_FILE
    ##innodb_buffer_pool_instances
    let BUFFER_POOL_INSTANCE=$MEM_CAP/2
    if [ $BUFFER_POOL_INSTANCE -lt 8 ]
    then
        BUFFER_POOL_INSTANCE=8
    elif [ $BUFFER_POOL_INSTANCE -gt 16 ]
    then
        BUFFER_POOL_INSTANCE=16
    else
        :
    fi
    echo "@type:common@0@999999@innodb_buffer_pool_instances = $BUFFER_POOL_INSTANCE" >> $TMP_FILE
    ##
    echo "@type:common@0@999999@innodb_read_io_threads = 16" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_write_io_threads = 8" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_purge_threads = 4" >> $TMP_FILE
    echo "@type:common@50704@999999@innodb_page_cleaners = $BUFFER_POOL_INSTANCE" >> $TMP_FILE
    ##innodb_flush_neighbors
    if [ $SSD_FLAG -eq 1 ]
    then
        echo "@type:common@50603@999999@innodb_flush_neighbors = 0" >> $TMP_FILE
    else
        echo "@type:common@50603@999999@innodb_flush_neighbors = 1" >> $TMP_FILE
    fi
    ##innodb_io_capacity
    let IO_CAP=$IO_CAP/2
    if [ $IO_CAP -gt 20000 ]
    then
        IO_CAP=20000
    fi
    echo "@type:common@0@999999@innodb_io_capacity = $IO_CAP" >> $TMP_FILE
    ##
    echo "@type:common@0@999999@innodb_flush_method = O_DIRECT" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_log_file_size = 2048M" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_log_group_home_dir = $DATA_DIR/redolog" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_log_files_in_group = 4" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_log_buffer_size = 32M" >> $TMP_FILE
    echo "@type:common@50603@999999@innodb_undo_directory = $DATA_DIR/undolog" >> $TMP_FILE
    echo "@type:common@50603@80013@innodb_undo_tablespaces = 3" >> $TMP_FILE
    echo "@type:common@50705@999999@innodb_undo_log_truncate = ON" >> $TMP_FILE
    echo "@type:common@50705@999999@innodb_max_undo_log_size = 4G" >> $TMP_FILE
    echo "@type:common@50603@999999@innodb_checksum_algorithm = crc32" >> $TMP_FILE
    ##innodb_thread_concurrency
    if [ $CPU_CORE_COUNT -lt 8 ]
    then
        THREAD_CONCURRENCY=8
    elif [ $CPU_CORE_COUNT -gt 128 ]
    then
        THREAD_CONCURRENCY=128
    else
        THREAD_CONCURRENCY=$CPU_CORE_COUNT
    fi
    echo "@type:common@0@999999@innodb_thread_concurrency = $THREAD_CONCURRENCY" >> $TMP_FILE
    ##
    echo "@type:common@0@999999@innodb_lock_wait_timeout = 10" >> $TMP_FILE
    echo "@type:common@50701@999999@innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:96G" >> $TMP_FILE
    echo "@type:common@50602@999999@innodb_print_all_deadlocks = ON" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_strict_mode = ON" >> $TMP_FILE
    echo "@type:common@0@999999@innodb_autoinc_lock_mode = 2" >> $TMP_FILE
    echo "@type:common@50606@999999@innodb_online_alter_log_max_size = 2G" >> $TMP_FILE
    echo "@type:common@50604@999999@innodb_sort_buffer_size = 2M" >> $TMP_FILE

    ##optional configuration
    echo "@type:common@0@999999@innodb_rollback_on_timeout = ON" >> $TMP_FILE
    echo "@type:common@0@999999@skip_name_resolve = ON" >> $TMP_FILE
    echo '@type:common@0@999999@performance_schema_instrument = "wait/lock/metadata/sql/mdl=ON"' >> $TMP_FILE

    ##Replication configuration
    if [ $REPL_ROLE = "M" ] ##Master
    then
        echo "@type:replication@0@999999@event_scheduler = ON" >> $TMP_FILE
        echo "@type:replication@0@999999@read_only = OFF" >> $TMP_FILE
        echo "@type:replication@50708@999999@super_read_only = OFF" >> $TMP_FILE
    else ##Slave
        echo "@type:replication@0@999999@event_scheduler = OFF" >> $TMP_FILE
        echo "@type:replication@0@999999@read_only = ON" >> $TMP_FILE
        echo "@type:replication@50708@999999@super_read_only = ON" >> $TMP_FILE
    fi
    ##Turn GTID on
    echo "@type:replication@0@999999@log_slave_updates = ON" >> $TMP_FILE
    echo "@type:replication@50605@999999@gtid_mode = ON" >> $TMP_FILE
    echo "@type:replication@50609@999999@enforce_gtid_consistency = ON" >> $TMP_FILE
    ##
    echo "@type:replication@0@999999@relay_log = $DATA_DIR/relaylog/relay.log" >> $TMP_FILE
    echo "@type:replication@50602@999999@master_info_repository = TABLE" >> $TMP_FILE
    echo "@type:replication@50602@999999@relay_log_info_repository = TABLE" >> $TMP_FILE
    echo "@type:replication@0@999999@relay_log_recovery = ON" >> $TMP_FILE
    echo "@type:replication@0@999999@skip_slave_start = ON" >> $TMP_FILE

    ##Semi sync replication
    echo '@type:semi-replication@0@999999@plugin_load = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"' >> $TMP_FILE
    echo "@type:semi-replication@0@999999@rpl_semi_sync_master_enabled = ON" >> $TMP_FILE
    echo "@type:semi-replication@0@999999@rpl_semi_sync_slave_enabled = ON" >> $TMP_FILE
    echo "@type:semi-replication@0@999999@rpl_semi_sync_master_timeout = 5000" >> $TMP_FILE
    echo "@type:semi-replication@50733@50799@replication_optimize_for_static_plugin_config = ON" >> $TMP_FILE
    echo "@type:semi-replication@80023@999999@replication_optimize_for_static_plugin_config = ON" >> $TMP_FILE
    echo "@type:semi-replication@50733@50799@replication_sender_observe_commit_only = ON" >> $TMP_FILE
    echo "@type:semi-replication@80023@999999@replication_sender_observe_commit_only = ON" >> $TMP_FILE

    ##Master master replication
    if [ $MM_FLAG -eq 1 ]
    then
        echo "@type:mm-replication@0@999999@auto_increment_offset = $AUTO_INCREMENT_OFFSET" >> $TMP_FILE
        echo "@type:mm-replication@0@999999@auto_increment_increment = 2" >> $TMP_FILE

        ##Turn off the event_scheduler is auto_increment_offset = 2
        if [ $AUTO_INCREMENT_OFFSET -eq 2 ]
        then
            sed -i "s/event_scheduler = ON/event_scheduler = OFF/g" $TMP_FILE
            EVENT_SCHEDULER='OFF'
        else
            EVENT_SCHEDULER='ON'
        fi
    fi

    ##Write my.cnf file
    echo "##This file is created by mycnf_helper for MySQL $SERVER_VERSION, use at your own risk(mycnf_helper_fingerprint)" > $MY_CNF
    echo '[mysqld]' >> $MY_CNF
    while read LINE
    do
        if [ $MYSQL_VERSION -ge `echo $LINE | cut -d'@' -f 3` ] && [ $MYSQL_VERSION -le `echo $LINE | cut -d'@' -f 4` ]
        then
            echo $LINE | cut -d'@' -f 5 >> $MY_CNF
        fi
    done < $TMP_FILE
    echo "##End(mycnf_helper_fingerprint)" >> $MY_CNF
else
    ##Check data directory whether it is empty or not exists
    DATA_DIR=`cat $F_FILE | grep datadir | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
    DATA_DIR=${DATA_DIR%*/}
    DATA_DIR=${DATA_DIR%/*}
    if [ -d $DATA_DIR ]
    then
        if [ `find $DATA_DIR -maxdepth 1 | wc -l` -gt 1 ]
        then
            DATADIR_NOT_EMPTY_FLAG=1
        fi
    fi

    ##Check base directory whether it is empty or not exists
    BASE_DIR=`cat $F_FILE | grep basedir | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
    BASE_DIR=${BASE_DIR%*/}
    if [ -d $BASE_DIR ]
    then
        if [ `find $BASE_DIR -maxdepth 1 | wc -l` -gt 1 ]
        then
            BASEDIR_NOT_EMPTY_FLAG=1
        fi
    fi
fi


##Check my.cnf file again, make sure it is complete
if [ $SKIP_GENERATE_MYCNF -eq 0 ]
then
    if [ `cat $MY_CNF | grep -c mycnf_helper_fingerprint` -ne 2 ]
    then
        error_quit "$MY_CNF is broken"
    fi
fi

if [ $SETUP_FLAG -eq 0 ]
then
    echo `tput bold`"Done!"`tput sgr0`
    exit 0
fi

if [[ $DATADIR_NOT_EMPTY_FLAG -eq 1 || $BASEDIR_NOT_EMPTY_FLAG -eq 1 ]]
then
    error_quit "Installation is forbidden because of no-empty directory for MySQL datadir or basedir"
fi


## Check OS version, installation only for CentOS and Red Hat
if [ `ls -l /etc | grep -c redhat-release` -gt 0 ]
then
    OS_INFO=`cat /etc/redhat-release`
    OS_VER_NUM=${OS_INFO%%.*}
    OS_INFO=${OS_INFO%% *}
    OS_VER_NUM=`echo $OS_VER_NUM | tr -cd "[0-9]"`
else
    error_quit "Can not find /etc/redhat-release"
fi

case $OS_INFO in
    Red)
        OS_INFO='RHEL';;
    CentOS)
        OS_INFO='CentOS';;
    *)
        error_quit "Unknown OS";;
esac
echo "OS type: "$OS_INFO $OS_VER_NUM


## Make sure the installation is operated by root only
if [ `whoami` != 'root' ]
then
    error_quit "Only support root installation"
fi


## Turn off the SELinux and firewall
if [ `getenforce` != 'Disabled' ]
then
    sed -i "/^SELINUX/d" /etc/selinux/config
    echo "SELINUX=disabled" >> /etc/selinux/config
    echo "SELINUXTYPE=targeted" >> /etc/selinux/config
    echo "Modifying /etc/selinux/config"
    setenforce 0
    echo `tput bold`"SELinux is disabled, rebooting OS is recommanded"`tput sgr0`
fi

if [ $OS_VER_NUM -lt 7 ]    ##for RHEL/CentOS 5,6
then
    chkconfig --level 2345 iptables off
    chkconfig --level 2345 ip6tables off
    service iptables stop
    service ip6tables stop
elif [[ $OS_VER_NUM -ge 7 && $OS_VER_NUM -lt 9 ]]    ##for RHEL/CentOS 7,8
then
    systemctl stop firewalld.service
    systemctl disable firewalld.service
else
    error_quit "Only support OS major version 5 ~ 8"
fi


## Check I/O scheduler, use noop for SSD, deadline for traditional hard disk
if [ $SKIP_GENERATE_MYCNF -eq 1 ]
then
    MY_CNF=$F_FILE
    INNODB_FLUSH_NEIGHBORS=`cat $MY_CNF | grep innodb_flush_neighbors | grep -v \# | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
    if [ -z "$INNODB_FLUSH_NEIGHBORS" ]
    then
        error_quit "Can not find innodb_flush_neighbors in $MY_CNF"
    fi

    if [ $INNODB_FLUSH_NEIGHBORS -eq 1 ]
    then
        SSD_FLAG=0
    else
        SSD_FLAG=1
    fi
fi
## Skip checking I/O scheduler in RHEL/CentOS 8 temporarily
if [ $OS_VER_NUM -lt 8 ]
then
    DEFAULT_IO_SCHEDULER=`dmesg | grep -i scheduler | grep default`
    if [[ $SSD_FLAG -eq 1 && `echo $DEFAULT_IO_SCHEDULER | grep -c noop` -eq 0 ]]
    then
        error_quit 'If you use SSD storage, please set innodb_flush_neighbors = 0 (current value) and I/O scheduler to noop. If you use traditional hard disk storage, please set innodb_flush_neighbors = 1 and I/O scheduler to deadline. Use "dmesg | grep -i scheduler" command to check your default I/O scheduler'
    elif [[ $SSD_FLAG -eq 0 && `echo $DEFAULT_IO_SCHEDULER | grep -c deadline` -eq 0 ]]
    then
        error_quit 'If you use SSD storage, please set innodb_flush_neighbors = 0 and I/O scheduler to noop. If you use traditional hard disk storage, please set innodb_flush_neighbors = 1 (current value) and I/O scheduler to deadline. Use "dmesg | grep -i scheduler" command to check your default I/O scheduler.'
    else
        echo "Check I/O scheduler:" $DEFAULT_IO_SCHEDULER
    fi
fi


## Phase innodb_buffer_pool_size from my.cnf
if [ $SKIP_GENERATE_MYCNF -eq 1 ]
then
    BUFFER_POOL=`cat $MY_CNF | grep innodb_buffer_pool_size | grep -v \# | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
    if [ -z "$BUFFER_POOL" ]
    then
        error_quit "Can not find innodb_buffer_pool_size in $MY_CNF"
    fi

    if [[ ${BUFFER_POOL:0-1} = 'G' || ${BUFFER_POOL:0-1} = 'g' ]]
    then
        BPL=${#BUFFER_POOL}
        let BPL=$BPL-1
        BUFFER_POOL=${BUFFER_POOL:0:$BPL}
        let BUFFER_POOL=$BUFFER_POOL*1024
    elif [[ ${BUFFER_POOL:0-1} = 'M' || ${BUFFER_POOL:0-1} = 'm' ]]
    then
        BPL=${#BUFFER_POOL}
        let BPL=$BPL-1
        BUFFER_POOL=${BUFFER_POOL:0:$BPL}
    else
        :
    fi
fi


## Try to fix "mysql: error while loading shared libraries: libtinfo.so.5" error
if [ ! -f "/usr/lib64/libtinfo.so.5" ] && [ -f "/usr/lib64/libtinfo.so.6.1" ]
then
	ln -s /usr/lib64/libtinfo.so.6.1 /usr/lib64/libtinfo.so.5
fi


## Tune Linux kernel parameter
if [ `cat /etc/sysctl.conf | grep -c mycnf_helper_fingerprint` -eq 0 ]
then
    echo '##The following contents are added by mycnf_helper(mycnf_helper_fingerprint)
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_mem = 524288 699050 1048576
net.core.netdev_max_backlog = 65535
net.core.somaxconn = 65535
net.core.wmem_default = 8388608
net.core.wmem_max = 16777216
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
kernel.hung_task_timeout_secs = 0
kernel.core_pattern = /var/log/core.%t
fs.file-max = 2000000' >> /etc/sysctl.conf

    ##vm.swappiness=1 or 0 depends on Linux kernel version, the goal is avoiding OOM killer
    KERNEL_VERSION_MAJOR=`uname -r | awk -F'.' '{print $1}'`
    KERNEL_VERSION=`uname -r | awk -F'.' '{print $1$2}'`
    if [[ $KERNEL_VERSION_MAJOR -lt 3 || $KERNEL_VERSION -lt 35 ]]
    then
        ##Linux 3.4 and below
        echo 'vm.swappiness = 0' >> /etc/sysctl.conf
    else
        ##Linux 3.5 and above
        echo 'vm.swappiness = 1' >> /etc/sysctl.conf
    fi

    ##kernel.shmmax=innodb_buffer_pool_size*1.2
    let SHMMAX=$BUFFER_POOL*1024*1024*6/5
    echo "kernel.shmmax = $SHMMAX" >> /etc/sysctl.conf
    echo "##End(mycnf_helper_fingerprint)" >> /etc/sysctl.conf

    #Bring the change into effect
    echo "Finish writing sysctl.conf"
    sysctl -p &>/dev/null
    if [ $? -eq 0 ]
    then
        echo "Finish executing sysctl -p"
    else
        error_quit "Executing 'sysctl -p' failed"
    fi
fi


## Configure OS limits
if [ `cat /etc/security/limits.conf | grep -v ^# | grep -v ^$ | grep -c mysql` -gt 0 ]
then
    if [ `cat /etc/security/limits.conf | grep -c mycnf_helper_fingerprint` -eq 0 ]
    then
        sed -i "s/^mysql/#&/g" /etc/security/limits.conf
        echo "Modifying /etc/security/limits.conf"
    fi
fi

if [ `cat /etc/security/limits.conf | grep -c mycnf_helper_fingerprint` -eq 0 ]
then
    echo '##The following contents are added by mycnf_helper(mycnf_helper_fingerprint)
mysql soft nofile 65535
mysql hard nofile 65535
mysql soft nproc 65535
mysql hard nproc 65535
##End(mycnf_helper_fingerprint)' >> /etc/security/limits.conf
    echo "Writing /etc/security/limits.conf"
fi

NPROC_CONF_CNT=`ls -l /etc/security/limits.d | grep -c nproc.conf`
if [ $NPROC_CONF_CNT -gt 0 ]
then
    if [ $NPROC_CONF_CNT -eq 1 ]
    then
        NPROC_CONF=`ls /etc/security/limits.d | grep nproc.conf`
        sed -i "/^*/d" /etc/security/limits.d/$NPROC_CONF
        echo "*          soft    nproc     65535" >> /etc/security/limits.d/$NPROC_CONF
        echo "Writing /etc/security/limits.d/"$NPROC_CONF
    else
        error_quit "mycnf_helper is confused because nproc.conf in /etc/security/limits.d directory is not unique"
    fi
fi

if [ `cat /etc/pam.d/login | grep -c pam_limits.so` -eq 0 ]
then
    echo "session    required    pam_limits.so" >> /etc/pam.d/login
    echo "Writing /etc/pam.d/login"
fi


## Clean up MariaDB if possible
if [ `rpm -qa | grep -c mariadb` -gt 0 ]
then
    echo "---------------------------------------- Find some MariaDB packages"
    rpm -qa | grep mariadb

    if [ `ps -ef | grep mysqld | grep -v grep | wc -l` -eq 0 ]
    then
        echo "Cleaning up the mariadb packages"
        rpm -e --nodeps `rpm -qa|grep -i mariadb`
    else
        echo "Find running mysqld process, MariaDB packages will not be cleaned up because it's too risky"
    fi
    echo "---------------------------------------- End line"
fi


## Install necessary packages
echo "Installing necessary packages..."
if [ $OS_VER_NUM -lt 8 ]
then
    yum install -y net-tools libaio libaio-devel numactl-libs ncurses-compat-libs numactl autoconf xz perl-Module* ntp &>/dev/null
else
    yum install -y net-tools libaio libaio-devel numactl-libs ncurses-compat-libs numactl autoconf xz perl-Module* &>/dev/null
fi
if [ $? -eq 1 ]
then
    error_quit "Install packeges from yum repository failed, please check your yum configuration first"
fi
echo "Finish installing necessary packages..."


## Check network port if occupied
if [ $SKIP_GENERATE_MYCNF -eq 1 ]
then
    MY_PORT=`cat $MY_CNF | grep port | grep -v \# | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
    if [ -z "$MY_PORT" ]
    then
        error_quit "Can not find port in $MY_CNF"
    fi
fi

if [ `netstat -tunlp | awk '{print $4}' | grep -E "*:$MY_PORT$" | wc -l` -gt 0 ]
then
    error_quit "Port $MY_PORT is occupied, please manually check"
fi


## Configure ntpdate
if [ $NTP_FLAG -eq 1 ]
then
    ## Check IP address format
    if [ `echo $NTP_SERVER | grep -E '^((2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)\.){3}(2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)$' | wc -l` -eq 0 ]
    then
        error_quit "Invalid IP address for NTP server, use -n to specify the right IP"
    fi

    if [ $OS_VER_NUM -lt 8 ] ## For CentOS/RHEL 5/6/7, use ntpdate
    then
        ## Create /var/spool/cron/root if not exists
        if [ ! -f /var/spool/cron/root ]
        then
            touch /var/spool/cron/root
            chmod 600 /var/spool/cron/root
            echo "Creating /var/spool/cron/root"
        fi

        if [ `cat /var/spool/cron/root | grep -c ntpdate` -eq 0 ]
        then
            echo "0 1 * * * /usr/sbin/ntpdate $NTP_SERVER" >> /var/spool/cron/root
            echo "Adding ntpdate $NTP_SERVER to root's crontab"
        else
            echo "ntpdate has already configured"
            crontab -l
        fi
    else ## For CentOS/RHEL 8, use chronyd
        if [ `cat /etc/chrony.conf | grep -v ^# | grep -v ^$ | grep ^pool | grep $NTP_SERVER | wc -l` -eq 0 ]
        then
            echo "Writing /etc/chrony.conf"
            sed -i "/^pool/d" /etc/chrony.conf
            echo "pool $NTP_SERVER" >> /etc/chrony.conf

            echo "Restarting chronyd"
            systemctl stop chronyd
            systemctl start chronyd
            systemctl enable chronyd
        fi
    fi
fi


## Check master's IP address if it's slave or master-master replication
if [[ $REPL_ROLE = 'S' || $MM_FLAG -eq 1 ]]
then
    if [ $MASTER_IP_FLAG -eq 1 ]
    then
        if [ `echo $MASTER_IP | grep -E '^((2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)\.){3}(2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)$' | wc -l` -eq 0 ]
        then
            error_quit "Invalid IP address for replication master, use -x to specify the right IP"
        fi
    fi
fi


## Check current server's IP address if it's specified
if [[ $MM_FLAG -eq 1 && $OWN_IP_FLAG -eq 1 ]]
then
    if [ `echo $OWN_IP | grep -E '^((2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)\.){3}(2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)$' | wc -l` -eq 0 ]
    then
        error_quit "Invalid IP address for current server, use -y to specify the right IP"
    fi
fi


## Create group and user
if [ `cat /etc/group | grep -c mysql:` -eq 0 ]
then
    echo "Creating group mysql"
    groupadd mysql
    if [ $? -ne 0 ]
    then
        error_quit "Create group 'mysql' failed"
    fi
fi

if [ `cat /etc/passwd | grep -c mysql:` -eq 0 ]
then
    echo "Creating user mysql"
    useradd -r -g mysql -s /bin/false mysql
    if [ $? -ne 0 ]
    then
        error_quit "Create user 'mysql' failed"
    fi
fi


## Check mysql-X.X.X*.tar.* in current directory
if [ `ls -l | grep -c mysql-$SERVER_VERSION-linux-glibc` -eq 1 ]
then
    MYSQL_PACKAGE=`ls | grep mysql-$SERVER_VERSION-linux-glibc`
    MYSQL_PACKAGE=$PWD/$MYSQL_PACKAGE
    echo "Find $MYSQL_PACKAGE for installation"
else
    error_quit "Can not find unique mysql-$SERVER_VERSION-linux-glibc archive package in current directory"
fi


## Uncompress MySQL binary package to BASE_DIR
if [ ! -d $BASE_DIR ]
then
    echo "Creating base directory $BASE_DIR"
    mkdir -p $BASE_DIR
    if [ $? -ne 0 ]
    then
        error_quit "Create base directory $BASE_DIR failed"
    fi
fi

echo "Executing tar -xvf $MYSQL_PACKAGE to $BASE_DIR..."
if [[ ${MYSQL_PACKAGE##*.} = 'gz' || ${MYSQL_PACKAGE##*.} = 'tar' ]]
then
    tar -xvf $MYSQL_PACKAGE -C $BASE_DIR --strip-components 1 &>/dev/null
elif [ ${MYSQL_PACKAGE##*.} = 'xz' ]
then
    xz -d $MYSQL_PACKAGE
    if [ $? -ne 0 ]
    then
        error_quit "Executing xz -d failed"
    fi
    tar -xvf ${MYSQL_PACKAGE%.*} -C $BASE_DIR --strip-components 1 &>/dev/null
else
    error_quit "Unknown package for uncompressing"
fi

if [ $? -ne 0 ]
then
    error_quit "Executing tar -xvf $MYSQL_PACKAGE to $BASE_DIR failed"
fi

echo "Changing $BASE_DIR's ownership"
chown -R mysql:mysql $BASE_DIR
if [ $? -ne 0 ]
then
    error_quit "Changing $BASE_DIR's ownership failed"
fi


## Create MySQL data directory
if [ ! -d $DATA_DIR ]
then
    echo "Creating root directory $DATA_DIR for MySQL datadir"
    mkdir -p $DATA_DIR
    if [ $? -ne 0 ]
    then
        error_quit "Create root directory $DATA_DIR for MySQL datadir failed"
    fi
fi

echo "Creating subdirectory for MySQL datadir"
mkdir $DATA_DIR/{data,tmp,binlog,slowlog,redolog,undolog,relaylog}
if [ $? -ne 0 ]
then
    error_quit "Creating subdirectory for MySQL datadir failed"
fi

echo "Preparing and backuping my.cnf file"
cp $MY_CNF $DATA_DIR/my.cnf
if [ $? -ne 0 ]
then
    error_quit "Preparing my.cnf file failed"
fi

echo "Changing $DATA_DIR's ownership"
chown -R mysql:mysql $DATA_DIR
if [ $? -ne 0 ]
then
    error_quit "Changing $DATA_DIR's ownership failed"
fi


## Configure root's .bash_profile
if [ `cat ~/.bash_profile | grep $BASE_DIR/bin | grep -c PATH` -eq 0 ]
then
    type mysql &>/dev/null
    if [ $? -ne 0 ]
    then
        echo "Writing root's .bash_profile"
        echo "export PATH=\$PATH:$BASE_DIR/bin" >> ~/.bash_profile
    fi
fi


## Initialize MySQL data directory
sed -i "/^rpl_semi_sync_/d" $MY_CNF ## Temporarily remove semi-replication variables for initialization defaults-file
echo "Initializing MySQL data directory..."
if [ $MYSQL_VERSION -lt 50700 ]
then
    $BASE_DIR/scripts/mysql_install_db --defaults-file=$MY_CNF --basedir=$BASE_DIR --user=mysql &>/dev/null
else
    $BASE_DIR/bin/mysqld --defaults-file=$MY_CNF --initialize-insecure --basedir=$BASE_DIR --user=mysql &>/dev/null
fi

if [ $? -ne 0 ]
then
    rm -rf $MY_CNF ## Clean up intermediate my.cnf to avoid misunderstanding
    error_quit "Initializing MySQL data directory failed, please check MySQL error log for further troubelshooting"
else
    echo "Initializing MySQL data directory succeed"
fi
rm -rf $MY_CNF ## Clean up intermediate my.cnf to avoid misunderstanding


## Startup mysqld process
echo "Starting mysqld process..."
$BASE_DIR/bin/mysqld_safe --defaults-file=$DATA_DIR/my.cnf --ledir=$BASE_DIR/bin &  ##--ledir option is compatibility for earlier version of MySQL 5.6.x
## Wait some seconds
while [[ $WAIT_TIME -ne 0 ]]
do
    sleep 1
    echo -n "."
    let WAIT_TIME=$WAIT_TIME-1
done
echo

if [ `ps -ef | grep mysqld | grep port=$MY_PORT | wc -l` -eq 1 ] && [ `netstat -tunlp | awk '{print $4}' | grep -E "*:$MY_PORT$" | wc -l` -eq 1 ]
then
    ps -ef | grep mysqld | grep port=$MY_PORT
    echo "Starting mysqld process succeed !!!"
else
    error_quit "Starting mysqld process failed"
fi


## Temporarily turn off super_read_only
ps -ef | grep port=$MY_PORT | grep mysqld | awk '{for(i=0;++i<=NF;)a[i]=a[i]?a[i] FS $i:$i}END{for(i=0;i++<NF;)print a[i]}' > $TMP_FILE
MYSQLD_SOCK=`cat $TMP_FILE | grep socket= | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
DATADIR_DATA=`cat $TMP_FILE | grep datadir= | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
PID_FILE=`cat $TMP_FILE | grep pid-file= | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
DEFAULTS_FILE=`cat $TMP_FILE | grep defaults-file= | sed "s/ //g" | awk -F'[=]' '{print $NF}'`

if [ $REPL_ROLE = 'S' ]    ##Slave
then
    SUPER_RO=`$BASE_DIR/bin/mysql -uroot -S$MYSQLD_SOCK -N --batch -e "SHOW VARIABLES LIKE 'super_read_only';" 2>/dev/null`
    if [ $? -ne 0 ]
    then
        error_quit "Getting super_read_only variable failed"
    fi

    if [ -n "$SUPER_RO" ]
    then
        $BASE_DIR/bin/mysql -uroot -S$MYSQLD_SOCK -e "SET GLOBAL super_read_only=OFF;" &>/dev/null
        if [ $? -ne 0 ]
        then
            error_quit "Turning off super_read_only failed"
        fi
    fi
fi


## Postinstallation: set root@localhost's password
echo "Postinstallation: set root@localhost's password: "`tput setaf 1; tput bold; tput rev`$ROOT_PASSWD`tput sgr0`
$BASE_DIR/bin/mysqladmin -uroot -S$MYSQLD_SOCK password $ROOT_PASSWD &>/dev/null
if [ $? -ne 0 ]
then
    error_quit "Setting root@localhost's password failed"
fi


## Postinstallation: clear anonymous database account and test database
echo "Postinstallation: clean up anonymous database account, test database, and create replication account"
$BASE_DIR/bin/mysql -uroot -p$ROOT_PASSWD -S$MYSQLD_SOCK -e "
DELETE FROM mysql.user WHERE user='' OR (user='root' AND host<>'localhost');
DELETE FROM mysql.db WHERE Db like 'test%';
CREATE USER 'repl'@'%' IDENTIFIED BY '$REPL_PASSWD';
GRANT REPLICATION SLAVE,SUPER ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
DROP DATABASE IF EXISTS test;
RESET MASTER;
" &>/dev/null
if [ $? -ne 0 ]
then
    error_quit "Cleaning up anonymous database account, test database, and create replication account failed"
fi
echo "Postinstallation: replication database account 'repl'@'%' has been created, password: "`tput setaf 1; tput bold; tput rev`$REPL_PASSWD`tput sgr0`


## Establish replication relationship
if [[ $REPL_ROLE = 'S' || $MM_FLAG -eq 1 ]]
then
    if [ $MASTER_IP_FLAG -eq 1 ]
    then
        ## Check server_id variable, make sure it's different between current mysqld and remote mysqld
        SERVER_ID_X=`$BASE_DIR/bin/mysql -urepl -p$REPL_PASSWD -h$MASTER_IP -N --batch -e "SHOW VARIABLES LIKE 'server_id';" 2>/dev/null | awk '{print $2}'`
        if [ -z "$SERVER_ID_X" ]
        then
            echo "Getting master's server_id failed, one-way replication will not be established"
            FAIL_FLAG=1
        else
            if [ $SERVER_ID_X -eq $SERVER_ID ]
            then
                echo "Illegal: master and slave have same server_id"
                FAIL_FLAG=1
            fi
        fi
        ## Execute "CHANGE MASTER TO" statement on current mysqld
        if [ $FAIL_FLAG -eq 0 ]
        then
            echo "Establishing one-way replication relationship by executing 'CHANGE MASTER TO' statement"
            $BASE_DIR/bin/mysql -uroot -p$ROOT_PASSWD -S$MYSQLD_SOCK -e "
            CHANGE MASTER TO MASTER_HOST='$MASTER_IP',MASTER_USER='repl',MASTER_PASSWORD='$REPL_PASSWD',MASTER_AUTO_POSITION=1;
            START SLAVE;"  &>/dev/null
            if [ $? -ne 0 ]
            then
                echo "Establishing one-way replication relationship failed"
                FAIL_FLAG=1
            else
                echo "Establishing one-way replication relationship succeed"
            fi
        fi
        ## Establish reversed replication relationship for master-master topology
        if [[ $OWN_IP_FLAG -eq 1 && $MM_FLAG -eq 1 && $FAIL_FLAG -eq 0 ]]
        then
            echo "Establishing master-master replication relationship by executing 'CHANGE MASTER TO' statement on remote server"
            AUTO_INCREMENT_OFFSET_X=`$BASE_DIR/bin/mysql -urepl -p$REPL_PASSWD -h$MASTER_IP -N --batch -e "SHOW VARIABLES LIKE 'auto_increment_offset';" 2>/dev/null | awk '{print $2}'`
            if [ -z "$AUTO_INCREMENT_OFFSET_X" ]
            then
                echo "Getting other side's auto_increment_offset failed, master-master replication will not be established"
                FAIL_FLAG=1
            fi
            AUTO_INCREMENT_INCREMENT_X=`$BASE_DIR/bin/mysql -urepl -p$REPL_PASSWD -h$MASTER_IP -N --batch -e "SHOW VARIABLES LIKE 'auto_increment_increment';" 2>/dev/null | awk '{print $2}'`
            if [ -z "$AUTO_INCREMENT_INCREMENT_X" ]
            then
                echo "Getting other side's auto_increment_increment failed, master-master replication will not be established"
                FAIL_FLAG=1
            fi
            EVENT_SCHEDULER_X=`$BASE_DIR/bin/mysql -urepl -p$REPL_PASSWD -h$MASTER_IP -N --batch -e "SHOW VARIABLES LIKE 'event_scheduler';" 2>/dev/null | awk '{print $2}'`
            if [ -z "$EVENT_SCHEDULER_X" ]
            then
                echo "Getting other side's event_scheduler failed, master-master replication will not be established"
                FAIL_FLAG=1
            fi
            ## Check auto_increment_offset, auto_increment_increment and event_scheduler variables
            if [ $FAIL_FLAG -eq 0 ]
            then
                if [[ $AUTO_INCREMENT_INCREMENT_X -eq 2 && $AUTO_INCREMENT_OFFSET_X -ne $AUTO_INCREMENT_OFFSET ]]
                then
                    if [[ $AUTO_INCREMENT_OFFSET_X -eq 1 || $AUTO_INCREMENT_OFFSET_X -eq 2 ]]
                    then
                        if [[ $EVENT_SCHEDULER_X = 'OFF' || $EVENT_SCHEDULER_X != $EVENT_SCHEDULER ]]
                        then
                            :
                        else
                            echo "Other side's event_scheduler and current mysqld's event_scheduler are both set to 'ON', it's risky in master-master replication"
                            echo "master-master replication will not be established"
                            FAIL_FLAG=1
                        fi
                    else
                        echo "Other side's auto_increment_offset not equal 1 or 2, master-master replication will not be established"
                        FAIL_FLAG=1
                    fi
                else
                    echo "Other side's auto_increment_increment not equal 2, or it's auto_increment_offset conflicts with current mysqld"
                    echo "master-master replication will not be established"
                    FAIL_FLAG=1
                fi
            fi
            ## Execute "CHANGE MASTER TO" statement on remote mysqld
            if  [ $FAIL_FLAG -eq 0 ]
            then
                $BASE_DIR/bin/mysql -urepl -p$REPL_PASSWD -h$MASTER_IP -e "
                CHANGE MASTER TO MASTER_HOST='$OWN_IP',MASTER_USER='repl',MASTER_PASSWORD='$REPL_PASSWD',MASTER_AUTO_POSITION=1;
                START SLAVE;"  &>/dev/null
                if [ $? -ne 0 ]
                then
                    echo "Establishing master-master replication relationship failed"
                else
                    echo "Establishing master-master replication relationship succeed"
                fi
            fi           
        fi
    fi
fi


## Turn on super_read_only
if [ $REPL_ROLE = 'S' ] && [ -n "$SUPER_RO" ]
then
    $BASE_DIR/bin/mysql -uroot -p$ROOT_PASSWD -S$MYSQLD_SOCK -e "SET GLOBAL super_read_only=ON;" &>/dev/null
    if [ $? -ne 0 ]
    then
        error_quit "Turning on super_read_only failed"
    fi
fi


## Configure mysqld as a service and enable autostart
if [ $AUTOSTART_FLAG -eq 1 ]
then
    read -p "Enable autostarting will overwrite /etc/my.cnf and /etc/init.d/mysqld. Enter 'YES' if you want to do this: " CONTINUE_FLAG
    if [[ `echo $CONTINUE_FLAG | tr [a-z] [A-Z]` = 'YES' ]]
    then
        if [ -f /etc/my.cnf ]
        then
            echo "Moving /etc/my.cnf to /etc/my.cnf.mycnf_helper.old"
            /bin/mv /etc/my.cnf /etc/my.cnf.mycnf_helper.old
            if [ $? -ne 0 ]
            then
                error_quit "Moving /etc/my.cnf to /etc/my.cnf.mycnf_helper.old failed"
            fi
        fi

        echo "Copying $DATA_DIR/my.cnf to /etc/my.cnf"
        /bin/cp $DATA_DIR/my.cnf /etc/my.cnf
        if [ $? -ne 0 ]
        then
            error_quit "Copying $DATA_DIR/my.cnf to /etc/my.cnf failed"
        fi

        if [ -f /etc/init.d/mysqld ]
        then
            echo "Moving /etc/init.d/mysqld to /etc/init.d/mysqld.mycnf_helper.old"
             /bin/mv /etc/init.d/mysqld /etc/init.d/mysqld.mycnf_helper.old
            if [ $? -ne 0 ]
            then
                error_quit "Moving /etc/init.d/mysqld to /etc/init.d/mysqld.mycnf_helper.old failed"
            fi
        fi

        echo "Copying $BASE_DIR/support-files/mysql.server to /etc/init.d/mysqld"
        /bin/cp $BASE_DIR/support-files/mysql.server /etc/init.d/mysqld
        if [ $? -ne 0 ]
        then
            error_quit "Copying $BASE_DIR/support-files/mysql.server to /etc/init.d/mysqld failed"
        fi

        echo "Modifying /etc/init.d/mysqld"
        sed -i "s|^basedir=$|basedir=$BASE_DIR|g" /etc/init.d/mysqld
        sed -i "s|^datadir=$|datadir=$DATADIR_DATA|g" /etc/init.d/mysqld
        sed -i "s|^mysqld_pid_file_path=$|mysqld_pid_file_path=$PID_FILE|g" /etc/init.d/mysqld
        chmod 755 /etc/init.d/mysqld
        if [ $? -ne 0 ]
        then
            error_quit "Modifying /etc/init.d/mysqld's privilege failed"
        fi

        if [ $OS_VER_NUM -lt 7 ]    ##for RHEL/CentOS 5,6
        then
            service mysqld stop
            chkconfig --del mysqld
            chkconfig --add mysqld
            chkconfig mysqld on
            service mysqld start
            service mysqld status
        elif [[ $OS_VER_NUM -ge 7 && $OS_VER_NUM -lt 9 ]]    ##for RHEL/CentOS 7,8
        then
            systemctl stop mysqld.service
            systemctl disable mysqld
            systemctl enable mysqld
            systemctl start mysqld.service
            systemctl status mysqld.service
        else
            error_quit "Only support OS major version 5 ~ 8"
        fi
    else
        echo "Operation canceled"
    fi
fi


## install tools
if [ $INSTALL_TOOLS_FLAG -eq 1 ]
then
    ## install XtraBackup
    FAIL_FLAG=0
    if [[ $OS_VER_NUM -gt 5 && $OS_VER_NUM -lt 9 ]]   ## now support RHEL/CentOS 6,7,8
    then
        if [ `rpm -qa | grep -c percona-xtrabackup` -eq 0 ]
        then
            echo "Installing XtraBackup..."
            yum install -y perl-DBI perl-DBD-MySQL rsync perl-Digest-MD5 &>/dev/null
            if [ $? -ne 0 ]
            then
                echo "Install packeges from yum repository failed, please check your yum configuration first."
                FAIL_FLAG=1
            fi

            if [ $FAIL_FLAG -eq 0 ]
            then
                QPRESS=`ls | grep ^qpress | grep el$OS_VER_NUM | head -1`
                LIBEV=`ls | grep ^libev | grep el$OS_VER_NUM | head -1`
                if [ $MYSQL_VERSION -lt 80000 ]
                then
                    XB=`ls | grep ^percona-xtrabackup-24 | grep el$OS_VER_NUM | head -1`
                else
                    XB=`ls | grep ^percona-xtrabackup-80 | grep el$OS_VER_NUM | head -1`
                fi
                
                if [ -n "$QPRESS" ] && [ -n "$LIBEV" ] && [ -n "$XB" ]
                then
                    rpm -ivh $QPRESS $LIBEV $XB
                    if [ $? -ne 0 ]
                    then
                        echo "Installing XtraBackup failed"
                        FAIL_FLAG=1
                    else
                        echo "Installing XtraBackup succeed"
                    fi
                else
                    echo "Lack of necessary packages, XtraBackup will not be installed"
                    FAIL_FLAG=1
                fi
            else
                echo "Skip installing XtraBackup"
            fi
        else
            echo "XtraBackup is already installed"
            rpm -qa | grep percona-xtrabackup
        fi
        ## print some recommadation
        if [ $FAIL_FLAG -eq 0 ]
        then
            OUTPUT_FILE="/dbbak/database/$(date +%Y%m%d%H%M)fullback.xbstream"
            echo "================================================================================"
            echo "You can use this command to create compressed full backup(recommanded on slave):"
            echo "xtrabackup --defaults-file=$DEFAULTS_FILE --backup --user=root \\"
            echo "--password=$ROOT_PASSWD --parallel=4 --slave-info \\"
            echo "--safe-slave-backup --stream=xbstream --compress --compress-threads=4 \\"
            echo "--socket=$MYSQLD_SOCK 2>/dbbak/backup.log 1>$OUTPUT_FILE"
            echo "================================================================================"
            echo "You can use these two commands to uncompress backup:"
            echo "xbstream -x < $OUTPUT_FILE -C /dbbak/uncompress"
            echo "xtrabackup -uroot -p$ROOT_PASSWD --socket=$MYSQLD_SOCK --decompress \\"
            echo "--remove-original --target-dir=/dbbak/uncompress"
            echo "================================================================================"
        fi
    else
        echo "Skip installing XtraBackup because OS version is too old or too new"
    fi
fi


echo `tput bold`"Everything succeed !!!"`tput sgr0`

