#!/bin/bash

echo '
Usage:
======================================================================================
-a: <flag>   Automatically gets CPU core count and memory capacity from current server
-c: <number> Logical CPU core count
-d: <string> datadir
-i: <number> server_id
-m: <number> Memory capacity(Unit: GB)
-o: <string> Destination of MySQL config file(Default: $PWD/my.cnf)
-p: <number> port(Default: 3306)
-s: <flag>   Setup the MySQL Server
-v: <string> MySQL Server version. eg: 5.6.32, 5.7.22, 8.0.18
======================================================================================
'

MY_CNF=$PWD/my.cnf
MY_PORT=3306
DATA_DIR=/data
TMP_FILE=/tmp/mycnf_helper.log
SERVER_ID=1


## Phase the option
while getopts "ac:d:i:m:o:p:sv:" opt
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
        i)
            SERVER_ID=$OPTARG;;
        m)
            MEM_CAP=$OPTARG;;
        o)
            MY_CNF=$OPTARG;;
        p)
            MY_PORT=$OPTARG;;
        s)
            SETUP_FLAG=1;;
        v)
            SERVER_VERSION=$OPTARG;;
        ?)
            echo "Unknown option, quit"
            exit 1;;
    esac
done


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


## Check MySQL Server version
if [ `echo $SERVER_VERSION | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'` ]
then
    if [ `echo ${SERVER_VERSION##*.} | wc -L` -eq 1 ]
    then
        MYSQL_VERSION=`echo $SERVER_VERSION | sed "s/\./0/g"`
    else
        MYSQL_VERSION=`echo $SERVER_VERSION | sed "s/\.//2g" | sed "s/\./0/g"`
    fi

    if [ $MYSQL_VERSION -lt 50600 ]
    then
        echo "MySQL Server version is too old to support, quit"
        exit 1
    fi

    echo "MySQL Server version: "$SERVER_VERSION\($MYSQL_VERSION\)
else
    echo "Invalid MySQL Server version, use -v to specify"
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
    echo "Please use absolute path with datadir, quit"
    exit 1
fi

if [ -d $DATA_DIR ]
then
    if [ `find $DATA_DIR -maxdepth 1 | wc -l` -gt 1 ]
    then
        echo $DATA_DIR "is not empty, quit"
        exit 1
    fi
fi
echo "MySQL data directory: "$DATA_DIR


## Generate the reference data
echo @type:common@0@999999@user = mysql > $TMP_FILE
echo @type:common@0@999999@port = $MY_PORT >> $TMP_FILE
echo @type:common@0@999999@server_id = $SERVER_ID >> $TMP_FILE
echo @type:common@0@999999@basedir = /usr/local/mysql >> $TMP_FILE
echo @type:common@0@999999@datadir = $DATA_DIR >> $TMP_FILE
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








if [[ $SETUP_FLAG -ne 1 ]]
then
    echo "Done!"
    exit 0
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
