#!/bin/bash

MY_CNF=$PWD/my.cnf
MY_PORT=3306
DATA_DIR=/mysql_data
TMP_FILE=/tmp/mycnf_helper.log
SETUP_FLAG=0
SERVER_ID=1
SSD_FLAG=0
IO_CAP=4000
SKIP_GENERATE_MYCNF=0
DIR_NOT_EMPTY_FLAG=0
MM_FLAG=0

## Phase the option
while getopts "ac:d:f:hi:I:m:M:o:p:r:sSv:" opt
do
    case $opt in
        a)
            CPU_CORE_COUNT=`cat /proc/cpuinfo| grep "processor"| wc -l`
            MEM_CAP=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
            let MEM_CAP=$MEM_CAP/1024/1024;;
        c)
            CPU_CORE_COUNT=$OPTARG;;
        d)
            DATA_DIR=$OPTARG;;
        f)
            F_FILE=$OPTARG
            SKIP_GENERATE_MYCNF=1;;
        h)
echo 'mycnf_helper has 2 main functions:
1): generating a my.cnf for MySQL Server with specific version(default behavior)
2): installing MySQL Server(with -s option)
===========================================
Usage:
-a:          automatically gets CPU core count and memory capacity from current server
-c: <number> logical CPU core count
-d: <string> MySQL initial data directory(default: /mysql_data)
-f: <string> specify a my.cnf for MySQL Server setup(this file should have mycnf_helper fingerprint)
-h:          print help information
-i: <number> server_id(default: 1)
-I: <number> IO capacity(IOPS) of the storage(default: 4000)
-m: <number> memory capacity(unit: GB)
-M: <number> use master-master replication and specify auto_increment_offset(1 or 2)
-o: <string> destination of MySQL config file(default: $PWD/my.cnf)
-p: <number> port(default: 3306)
-r: <string> replication role, must be master or slave
-s:          generate a my.cnf file and setup the MySQL Server
-S:          use SSD storage(for innodb_flush_neighbors)
-v: <string> MySQL Server version. eg: 5.6.32, 5.7.22, 8.0.1
'
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
        v)
            SERVER_VERSION=$OPTARG;;
        ?)
            echo "Unknown option, quit"
            exit 1;;
    esac
done


if [ $SKIP_GENERATE_MYCNF -eq 1 ] && [ $SETUP_FLAG -eq 0 ]
then
    echo "Nothing need to be done, quit"
    exit 0
fi


if [ $SKIP_GENERATE_MYCNF -eq 0 ]
then
    
    ## Make sure the CPU core count is digit
    if [ `echo $CPU_CORE_COUNT | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "CPU core count: "$CPU_CORE_COUNT" cores"
    else
        echo "Invalid CPU core count, use -c to specify"
        exit 1
    fi
    
    ## Make sure the memory capacity is digit
    if [ `echo $MEM_CAP | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "Memory capacity: "$MEM_CAP"GB"
    else
        echo "Invalid memory capacity, use -m to specify"
        exit 1
    fi
    
    ## Make sure the port is digit
    if [ `echo $MY_PORT | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "MySQL Server port: "$MY_PORT
    else
        echo "Invalid port number, use -p to specify"
        exit 1
    fi
    
    ## Make sure the server_id is digit
    if [ `echo $SERVER_ID | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "MySQL Server server_id: "$SERVER_ID
    else
        echo "Invalid server_id, use -i to specify"
        exit 1
    fi
    
    ## Make sure the IOPS is digit
    if [ `echo $IO_CAP | sed -n '/^[1-9][0-9]*$/p'` ]
    then
        echo "IO capacity: "$IO_CAP "IOPS"
    else
        echo "Invalid IO capacity, use -I to specify"
        exit 1
    fi
    
    ## Check the destination of my.cnf
    if [ ${MY_CNF:0:1} != '/' ]
    then
        echo 'Please use absolute path with my.cnf file, quit'
        exit 1
    fi
    
    if [ -f $MY_CNF ]
    then
        echo $MY_CNF" has already exists, overwriting is not supported"
        exit 1
    else
        MY_DIR=${MY_CNF%/*}
        if [ ! -d $MY_DIR ]
        then
            echo $MY_DIR" does not exists"
            exit 1
        else
            ##touch $MY_CNF
            echo "MySQL config file will be created: "$MY_CNF
        fi
    fi
    
    ## Check the data directory, must be empty or not exist
    DATA_DIR=${DATA_DIR%*/}
    if [ ${DATA_DIR:0:1} != '/' ]
    then
        echo "Please use absolute path for datadir, quit"
        exit 1
    fi
    
    echo "MySQL data directory: "$DATA_DIR
    if [ -d $DATA_DIR ]
    then
        if [ `find $DATA_DIR -maxdepth 1 | wc -l` -gt 1 ]
        then
            echo "Be carefull, "$DATA_DIR "is not empty"
            DIR_NOT_EMPTY_FLAG=1
        fi
    fi
    
    ## Check replication role
    if [ `echo $REPL_ROLE | grep -i slave | wc -l` -eq 1 ]
    then
        REPL_ROLE=S
        echo "Replication role: slave"
    elif [ `echo $REPL_ROLE | grep -i master | wc -l` -eq 1 ]
    then
        REPL_ROLE=M
        echo "Replication role: master"
    else
        echo "Replication role must be slave or master, use -r to specify"
        exit 1
    fi

    ## Check AUTO_INCREMENT_OFFSET
    if [ $MM_FLAG -eq 1 ]
    then
        if [ $AUTO_INCREMENT_OFFSET -eq 1 ] || [ $AUTO_INCREMENT_OFFSET -eq 2 ]
        then
            echo "Master-Master replication is enabled, auto_increment_offset="$AUTO_INCREMENT_OFFSET
        else
            echo "Invalid auto_increment_offset, use -M to specify(1 or 2)"
            exit 1
        fi
    fi

else
    if [ -f $F_FILE ]
    then
        if [ `cat $F_FILE | grep mycnf_helper_fingerprint | wc -l` -ne 2 ]
        then
            echo $F_FILE "does not has mycnf_helper fingerprint, quit"
            exit 1
        else
            echo $F_FILE "will be used to setup the MySQL Server"
        fi
    else
        echo $F_FILE "does not exists, quit"
        exit 1
    fi
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

    if [ $MYSQL_VERSION -lt 50609 ]
    then
        echo "MySQL Server version is too old to be supported, quit"
        exit 1
    fi

    echo "MySQL Server version: "$SERVER_VERSION\($MYSQL_VERSION\)
else
    echo "Invalid MySQL Server version, use -v to specify"
    exit 1    
fi


## Generate the reference data
if [ $SKIP_GENERATE_MYCNF -eq 0 ]
then
    echo @type:header@999999@0@this is a temporary file for mycnf_helper > $TMP_FILE
    echo @type:common@0@999999@user = mysql >> $TMP_FILE
    echo @type:common@0@999999@port = $MY_PORT >> $TMP_FILE
    echo @type:common@0@999999@server_id = $SERVER_ID >> $TMP_FILE
    echo @type:common@0@999999@basedir = /usr/local/mysql >> $TMP_FILE
    echo @type:common@0@999999@datadir = $DATA_DIR/data >> $TMP_FILE
    echo @type:common@0@999999@tmpdir = $DATA_DIR/tmp >> $TMP_FILE
    echo @type:common@0@999999@socket = $DATA_DIR/mysql.sock >> $TMP_FILE
    echo @type:common@50715@999999@mysqlx_socket = $DATA_DIR/mysqlx.sock >> $TMP_FILE
    echo @type:common@0@999999@pid_file = $DATA_DIR/mysql.pid >> $TMP_FILE
    echo @type:common@0@999999@autocommit = ON >> $TMP_FILE
    echo @type:common@0@999999@character_set_server = utf8mb4 >> $TMP_FILE
    echo @type:common@0@999999@collation_server = utf8mb4_unicode_ci >> $TMP_FILE
    echo @type:common@0@50719@tx_isolation = READ-COMMITTED >> $TMP_FILE
    echo @type:common@50720@999999@transaction_isolation = READ-COMMITTED >> $TMP_FILE
    echo @type:common@0@999999@lower_case_table_names = 1 >> $TMP_FILE
    echo @type:common@0@999999@sync_binlog = 1 >> $TMP_FILE
    echo @type:common@0@999999@secure_file_priv = $DATA_DIR/tmp >> $TMP_FILE
    echo @type:common@0@999999@log_bin = $DATA_DIR/binlog/bin.log >> $TMP_FILE
    echo @type:common@0@999999@binlog_format = ROW >> $TMP_FILE
    echo @type:common@0@80000@expire_logs_days = 15 >> $TMP_FILE
    echo @type:common@80001@999999@binlog_expire_logs_seconds = 1296000 >> $TMP_FILE
    echo @type:common@50602@999999@binlog_rows_query_log_events = ON >> $TMP_FILE
    echo @type:common@0@999999@log_bin_trust_function_creators = ON >> $TMP_FILE
    echo @type:common@0@999999@log_error = $DATA_DIR/error.log >> $TMP_FILE
    echo @type:common@0@999999@slow_query_log = ON >> $TMP_FILE
    echo @type:common@0@999999@slow_query_log_file = $DATA_DIR/slowlog/slow.log >> $TMP_FILE
    echo @type:common@0@999999@log_queries_not_using_indexes = ON >> $TMP_FILE
    echo @type:common@50605@999999@log_throttle_queries_not_using_indexes = 10 >> $TMP_FILE
    echo @type:common@0@999999@long_query_time = 2 >> $TMP_FILE
    echo @type:common@50611@999999@log_slow_admin_statements = ON >> $TMP_FILE
    echo @type:common@50611@999999@log_slow_slave_statements = ON >> $TMP_FILE
    echo @type:common@0@999999@min_examined_row_limit = 100 >> $TMP_FILE
    echo @type:common@50702@999999@log_timestamps = SYSTEM >> $TMP_FILE
    echo @type:common@0@50723@sql_mode = NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,ONLY_FULL_GROUP_BY >> $TMP_FILE
    echo @type:common@50724@999999@sql_mode = NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,ONLY_FULL_GROUP_BY >> $TMP_FILE
    echo @type:common@0@50703@metadata_locks_hash_instances = 256 >> $TMP_FILE
    echo @type:common@50606@999999@table_open_cache_instances = 16 >> $TMP_FILE
    echo @type:common@0@999999@max_connections = 800 >> $TMP_FILE
    echo @type:common@0@999999@max_allowed_packet = 256M >> $TMP_FILE
    echo @type:common@0@999999@join_buffer_size = 2M >> $TMP_FILE
    echo @type:common@0@999999@read_buffer_size = 2M >> $TMP_FILE
    echo @type:common@0@999999@binlog_cache_size = 2M >> $TMP_FILE
    echo @type:common@0@999999@read_rnd_buffer_size = 2M >> $TMP_FILE
    echo @type:common@0@999999@key_buffer_size = 16M >> $TMP_FILE
    echo @type:common@0@999999@tmp_table_size = 32M >> $TMP_FILE
    echo @type:common@0@999999@max_heap_table_size = 32M >> $TMP_FILE
    echo @type:common@0@999999@interactive_timeout = 7200 >> $TMP_FILE
    echo @type:common@0@999999@wait_timeout = 7200 >> $TMP_FILE
    echo @type:common@0@999999@max_connect_errors = 1000000 >> $TMP_FILE
    echo @type:common@0@999999@lock_wait_timeout = 3600 >> $TMP_FILE
    echo @type:common@0@999999@thread_cache_size = 64 >> $TMP_FILE
    echo @type:common@0@999999@myisam_sort_buffer_size = 32M >> $TMP_FILE
    echo @type:common@50622@50699@binlog_error_action = ABORT_SERVER >> $TMP_FILE
    echo @type:common@50706@999999@binlog_error_action = ABORT_SERVER >> $TMP_FILE
    echo @type:common@0@999999@innodb_file_per_table = ON >> $TMP_FILE
    echo @type:common@0@50799@innodb_file_format = Barracuda >> $TMP_FILE
    echo @type:common@0@50799@innodb_file_format_max = Barracuda >> $TMP_FILE
    echo @type:common@50603@50799@innodb_large_prefix = ON >> $TMP_FILE
    echo @type:common@0@999999@innodb_flush_log_at_trx_commit = 1 >> $TMP_FILE
    echo @type:common@50602@999999@innodb_stats_persistent_sample_pages = 128 >> $TMP_FILE
    ##innodb_buffer_pool_size
    let BUFFER_POOL=$MEM_CAP*1024*7/10
    let BPL=${#BUFFER_POOL}
    let BPL=BPL-2
    echo @type:common@0@999999@innodb_buffer_pool_size = ${BUFFER_POOL:0:$BPL}00M >> $TMP_FILE
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
    echo @type:common@0@999999@innodb_buffer_pool_instances = $BUFFER_POOL_INSTANCE >> $TMP_FILE
    ##
    echo @type:common@0@999999@innodb_read_io_threads = 16 >> $TMP_FILE
    echo @type:common@0@999999@innodb_write_io_threads = 8 >> $TMP_FILE
    echo @type:common@0@999999@innodb_purge_threads = 4 >> $TMP_FILE
    echo @type:common@50704@999999@innodb_page_cleaners = $BUFFER_POOL_INSTANCE >> $TMP_FILE
    ##innodb_flush_neighbors
    if [ $SSD_FLAG -eq 1 ]
    then
        echo @type:common@50603@999999@innodb_flush_neighbors = 0 >> $TMP_FILE
    else
        echo @type:common@50603@999999@innodb_flush_neighbors = 1 >> $TMP_FILE
    fi
    ##innodb_io_capacity
    let IO_CAP=$IO_CAP/2
    if [ $IO_CAP -gt 20000 ]
    then
        IO_CAP=20000
    fi
    echo @type:common@0@999999@innodb_io_capacity = $IO_CAP >> $TMP_FILE
    ##
    echo @type:common@0@999999@innodb_flush_method = O_DIRECT >> $TMP_FILE
    echo @type:common@0@999999@innodb_log_file_size = 2048M >> $TMP_FILE
    echo @type:common@0@999999@innodb_log_group_home_dir = $DATA_DIR/redolog >> $TMP_FILE
    echo @type:common@0@999999@innodb_log_files_in_group = 4 >> $TMP_FILE
    echo @type:common@0@999999@innodb_log_buffer_size = 32M >> $TMP_FILE
    echo @type:common@50603@999999@innodb_undo_directory = $DATA_DIR/undolog >> $TMP_FILE
    echo @type:common@50603@80013@innodb_undo_tablespaces = 3 >> $TMP_FILE
    echo @type:common@50705@999999@innodb_undo_log_truncate = ON >> $TMP_FILE
    echo @type:common@50705@999999@innodb_max_undo_log_size = 4G >> $TMP_FILE
    echo @type:common@50603@999999@innodb_checksum_algorithm = crc32 >> $TMP_FILE
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
    echo @type:common@0@999999@innodb_thread_concurrency = $THREAD_CONCURRENCY >> $TMP_FILE
    ##
    echo @type:common@0@999999@innodb_lock_wait_timeout = 10 >> $TMP_FILE
    echo @type:common@50701@999999@innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:96G >> $TMP_FILE
    echo @type:common@50602@999999@innodb_print_all_deadlocks = ON >> $TMP_FILE
    echo @type:common@0@999999@innodb_strict_mode = ON >> $TMP_FILE
    echo @type:common@0@999999@innodb_autoinc_lock_mode = 2 >> $TMP_FILE
    echo @type:common@50606@999999@innodb_online_alter_log_max_size = 2G >> $TMP_FILE
    echo @type:common@50604@999999@innodb_sort_buffer_size = 2M >> $TMP_FILE

    ##optional configuration
    echo @type:common@0@999999@innodb_rollback_on_timeout = ON >> $TMP_FILE
    echo @type:common@0@999999@skip_name_resolve = ON >> $TMP_FILE
    echo '@type:common@0@999999@performance_schema_instrument = "wait/lock/metadata/sql/mdl=ON"' >> $TMP_FILE

    ##Replication configuration
    if [ $REPL_ROLE = "M" ] ##Master
    then
        echo @type:replication@0@999999@event_scheduler = ON >> $TMP_FILE
        echo @type:replication@0@999999@read_only = OFF >> $TMP_FILE
        echo @type:replication@50708@999999@super_read_only = OFF >> $TMP_FILE
    else ##Slave
        echo @type:replication@0@999999@event_scheduler = OFF >> $TMP_FILE
        echo @type:replication@0@999999@read_only = ON >> $TMP_FILE
        echo @type:replication@50708@999999@super_read_only = ON >> $TMP_FILE
    fi
    ##Turn GTID on
    echo @type:replication@0@999999@log_slave_updates = ON >> $TMP_FILE
    echo @type:replication@50605@999999@gtid_mode = ON >> $TMP_FILE
    echo @type:replication@50609@999999@enforce_gtid_consistency = ON >> $TMP_FILE
    ##
    echo @type:replication@0@999999@relay_log = $DATA_DIR/relaylog/relay.log >> $TMP_FILE
    echo @type:replication@50602@999999@master_info_repository = TABLE >> $TMP_FILE
    echo @type:replication@50602@999999@relay_log_info_repository = TABLE >> $TMP_FILE
    echo @type:replication@0@999999@relay_log_recovery = ON >> $TMP_FILE
    echo @type:replication@0@999999@skip_slave_start = ON >> $TMP_FILE

    ##Semi sync replication
    echo '@type:semi-replication@0@999999@plugin_load = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"' >> $TMP_FILE
    echo @type:semi-replication@0@999999@rpl_semi_sync_master_enabled = ON >> $TMP_FILE
    echo @type:semi-replication@0@999999@rpl_semi_sync_slave_enabled = ON >> $TMP_FILE
    echo @type:semi-replication@0@999999@rpl_semi_sync_master_timeout = 5000 >> $TMP_FILE
    
    ##Master master replication
    if [ $MM_FLAG -eq 1 ]
    then
        echo @type:mm-replication@0@999999@auto_increment_offset = $AUTO_INCREMENT_OFFSET >> $TMP_FILE
        echo @type:mm-replication@0@999999@auto_increment_increment = 2 >> $TMP_FILE
    fi
    
    
    ##Write my.cnf file
    echo "##This file is created by mycnf_helper for MySQL "$SERVER_VERSION", use at your own risk(mycnf_helper_fingerprint)" > $MY_CNF
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
            DIR_NOT_EMPTY_FLAG=1
        fi
    fi
fi


##Check my.cnf file agein, make sure it is complete
if [ $SKIP_GENERATE_MYCNF -eq 0 ]
then
    if [ `cat $MY_CNF | grep mycnf_helper_fingerprint | wc -l` -ne 2 ]
    then
        echo $MY_CNF "is broken, quit"
        exit 1
    fi
fi


if [ $SETUP_FLAG -eq 0 ]
then
    echo "Done!"
    exit 0
fi

if [ $DIR_NOT_EMPTY_FLAG -eq 1 ]
then
    echo "Installing is forbidden because of no-empty directory for MySQL initial data directory"
    exit 1
fi


## Check OS version, installation only for CentOS, Red Hat or Fedora
if [ `ls -l /etc | grep system-release\  | wc -l` -lt 1 ]
then
    echo "Unknown OS, quit 1"
    exit 1
else
    OS_INFO=`cat /etc/system-release`
fi

OS_INFO=${OS_INFO%% *}

case $OS_INFO in
    Red) 
        OS_INFO='RHEL';;
    CentOS) 
        OS_INFO='CentOS';;
    ##Fedora) 
        ##OS_INFO='Fedora';;
    *) 
        echo "Unknown OS, quit 2"; exit 1;;
esac

echo "OS type: $OS_INFO"


## Make sure the installation is operated by root only
if [ `whoami` != 'root' ]
then
    echo "Support root installation only, quit"
    exit 1
fi


## Check I/O scheduler, use noop for SSD, deadline for traditional hard disk
if [ $SKIP_GENERATE_MYCNF -eq 1 ]
then
    INNODB_FLUSH_NEIGHBORS=`cat $MY_CNF | grep innodb_flush_neighbors | grep -v \# | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
    if [ -z "$INNODB_FLUSH_NEIGHBORS" ]
    then
        echo "Can not find innodb_flush_neighbors in "$MY_CNF
        exit 1
    fi

    if [ $INNODB_FLUSH_NEIGHBORS -eq 1 ]
    then
        SSD_FLAG=0
    else
        SSD_FLAG=1
    fi
fi

DEFAULT_IO_SCHEDULER=`dmesg | grep -i scheduler | grep default`
if [ $SSD_FLAG -eq 1 ] && [ `echo $DEFAULT_IO_SCHEDULER | grep noop | wc -l` -eq 0 ]
then
    echo "If you use SSD storage, please set innodb_flush_neighbors=0(current value) and I/O scheduler to noop."
    echo "If you use traditional hard disk storage, please set innodb_flush_neighbors=1 and I/O scheduler to deadline."
    echo "use 'dmesg | grep -i scheduler' command to check your default I/O scheduler."
    exit 1
elif [ $SSD_FLAG -eq 0 ] && [ `echo $DEFAULT_IO_SCHEDULER | grep deadline | wc -l` -eq 0 ]
then
    echo "If you use SSD storage, please set innodb_flush_neighbors=0 and I/O scheduler to noop."
    echo "If you use traditional hard disk storage, please set innodb_flush_neighbors=1(current value) and I/O scheduler to deadline."
    echo "use 'dmesg | grep -i scheduler' command to check your default I/O scheduler."
    exit 1
else
    echo "Check I/O scheduler:" $DEFAULT_IO_SCHEDULER
fi


## Phase innodb_buffer_pool_size from my.cnf
if [ $SKIP_GENERATE_MYCNF -eq 1 ]
then
    MY_CNF=$F_FILE
    BUFFER_POOL=`cat $MY_CNF | grep innodb_buffer_pool_size | grep -v \# | sed "s/ //g" | awk -F'[=]' '{print $NF}'`
    if [ -z "$BUFFER_POOL" ]
    then
        echo "Can not find innodb_buffer_pool_size in "$MY_CNF
        exit 1
    fi

    if [ ${BUFFER_POOL:0-1} = 'G' ] || [ ${BUFFER_POOL:0-1} = 'g' ]
    then
        let BPL=${#BUFFER_POOL}
        let BPL=BPL-1
        BUFFER_POOL=${BUFFER_POOL:0:$BPL}
        let BUFFER_POOL=$BUFFER_POOL*1024
        
    elif [ ${BUFFER_POOL:0-1} = 'M' ] || [ ${BUFFER_POOL:0-1} = 'm' ]
    then
        let BPL=${#BUFFER_POOL}
        let BPL=BPL-1
        BUFFER_POOL=${BUFFER_POOL:0:$BPL}
    else
        :
    fi
fi


## Tune Linux kernel parameter
if [ `cat /etc/sysctl.conf | grep mycnf_helper_fingerprint | wc -l` -eq 0 ]
then
    echo '##The following contents are added by mycnf_helper(mycnf_helper_fingerprint)=============
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
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
fs.file-max = 2000000
vm.swappiness = 1' >> /etc/sysctl.conf

    ##kernel.shmmax=innodb_buffer_pool_size*1.2
    let SHMMAX=BUFFER_POOL*1024*1024*6/5
    echo kernel.shmmax = $SHMMAX >> /etc/sysctl.conf
    echo "##End(mycnf_helper_fingerprint)" >> /etc/sysctl.conf

    #Bring the change into effect
    echo "---------------------------------------- Finish writing sysctl.conf"
    sysctl -p
    echo "---------------------------------------- Finish executing sysctl -p"
fi


## Configure OS limits
if [ `cat /etc/security/limits.conf | grep -v ^# | grep -v ^$ | grep mysql | wc -l` -gt 0 ]
then
    if [ `cat /etc/security/limits.conf | grep mycnf_helper_fingerprint | wc -l` -eq 0 ]
    then
        sed -i "s/^mysql/#&/g" /etc/security/limits.conf
        echo "modifying /etc/security/limits.conf"
    fi
fi

if [ `cat /etc/security/limits.conf | grep mycnf_helper_fingerprint | wc -l` -eq 0 ]
then
    echo '##The following contents are added by mycnf_helper(mycnf_helper_fingerprint)=============
mysql soft nofile 65535
mysql hard nofile 65535
mysql soft nproc 65535
mysql hard nproc 65535
##End(mycnf_helper_fingerprint)' >> /etc/security/limits.conf
    echo "writing /etc/security/limits.conf"
fi

NPROC_CONF_CNT=`ls -l /etc/security/limits.d | grep nproc.conf | wc -l`
if [ $NPROC_CONF_CNT -gt 0 ]
then
    if [ $NPROC_CONF_CNT -eq 1 ]
    then
        NPROC_CONF=`ls /etc/security/limits.d | grep nproc.conf`
        sed -i "/^*/d" /etc/security/limits.d/$NPROC_CONF
        echo "*          soft    nproc     65535" >> /etc/security/limits.d/$NPROC_CONF
        echo "writing /etc/security/limits.d/"$NPROC_CONF
    else
        echo "mycnf_helper is confused because nproc.conf in /etc/security/limits.d directory is not unique"
        exit 1
    fi
fi

if [ `cat /etc/pam.d/login | grep pam_limits.so | wc -l` -eq 0 ]
then
    echo "session    required    pam_limits.so" >> /etc/pam.d/login
    echo "Writing /etc/pam.d/login"
fi




## Turn off the SeLinux and firewall




##DATA_DIR's sub directory
##data, tmp, binlog, slowlog, redolog, undolog, relaylog
