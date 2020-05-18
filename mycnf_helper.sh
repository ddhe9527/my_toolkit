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

## Phase the option
while getopts "ac:d:f:hi:I:m:o:p:sSv:" opt
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
-a: <flag>   automatically gets CPU core count and memory capacity from current server
-c: <number> logical CPU core count
-d: <string> datadir(default: /mysql_data)
-f: <string> specify a my.cnf for MySQL Server setup(this file should have mycnf_helper fingerprint)
-h: <flag>   print help information
-i: <number> server_id(default: 1)
-I: <number> IO capacity(IOPS) of the storage(default: 4000)
-m: <number> memory capacity(unit: GB)
-o: <string> destination of MySQL config file(default: $PWD/my.cnf)
-p: <number> port(default: 3306)
-s: <flag>   generate a my.cnf file and setup the MySQL Server
-S: <flag>   use SSD storage(for innodb_flush_neighbors)
-v: <string> MySQL Server version. eg: 5.6.32, 5.7.22, 8.0.1
'
            exit 0;;
        i)
            SERVER_ID=$OPTARG;;
        I)
            IO_CAP=$OPTARG;;
        m)
            MEM_CAP=$OPTARG;;
        o)
            MY_CNF=$OPTARG;;
        p)
            MY_PORT=$OPTARG;;
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
        echo "IO capacity: "$IO_CAP
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
else
    if [ -f $F_FILE ]
    then
        if [ `cat $F_FILE | grep mycnf_helper_fingerprint | wc -l` -ne 1 ]
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

    if [ $MYSQL_VERSION -lt 50603 ]
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
    echo @type:header@this is a temporary file for mycnf_helper > $TMP_FILE
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
    echo @type:common@0@999999@innodb_buffer_pool_size = ${BUFFER_POOL:0:-2}00M >> $TMP_FILE
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
    
fi


##DATA_DIR's sub directory
##data, tmp, binlog, slowlog, redolog, undolog, 


if [ $SETUP_FLAG -eq 0 ]
then
    echo "Done!"
    exit 0
fi

if [ $DIR_NOT_EMPTY_FLAG -eq 1 ]
then
    echo "Installing is forbidden because of no-empty directory for datadir"
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
