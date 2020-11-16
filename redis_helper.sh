#!/bin/sh


## Default values
REDIS_CONFIG_FILE=$PWD/redis.conf
SENTINEL_CONFIG_FILE=$PWD/sentinel.conf
LOWEST_VERSION='003000000'
MEM_CAP=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
let MEM_CAP=$MEM_CAP/1024-200
MEM_USED=$MEM_CAP"mb"


## Flags(internal use)
SET_VERSION_FLAG=0
SET_DIR_FLAG=0
SET_MEM_FLAG=0
SET_PORT_FLAG=0
SENTINEL_FLAG=0
SKIP_GENERATE_CNF=0
SETUP_FLAG=0
SET_OUTPUT_FLAG=0
SET_RDB_FLAG=0
SET_AOF_FLAG=0
SET_REPL_FLAG=0
SET_CLUSTER_FLAG=0
SET_SENTINEL_MONITOR_FLAG=0
SET_PASSWORD_FLAG=0
SET_MASTER_PASSWORD_FLAG=0


## Function: -h option, print help information
function usage()
{
echo "=====================================================================================================
Usage:
-A：         enable AOF persistence(default: disable)
-c:          enable Redis Cluster mode(default: disable)
-d: <string> redis dir(default: ./ or /tmp if it's sentinel)
-f: <string> specify configuration file for installation(this file should have redis_helper fingerprint)
-h:          print help information and quit
-m: <number> specify maxmemory with 'mb' unit(default: total memory capacity minus 200mb)
-M: <string> set sentinel monitor, format: MASTER_NAME:IP:PORT:QUORUM. eg: -M mymaster:127.0.0.1:6379:2
-o: <string> destination of configuration file(default: \$PWD/redis.conf or \$PWD/sentinel.conf)
-p: <number> port(default: 6379 or 26379 if it's sentinel)
-P: <string> set password(requirepass) for this instance(default: no password)
-r: <string> set replicaof(slaveof), format: IP:PORT. eg: -r 192.168.0.2:6379
-R:          enable RDB persistence(default: disable)
-s:          installation type: sentinel
-S:          install redis binary program and start the instance
-v: <string> Redis Server version. eg: 3.0.6, 3.2.13, 4.0.1, 5.0.2, 6.0.9
-x: <string> if master has password, set masterauth on replica, or sentinel auth-pass on sentinel
=====================================================================================================
Github: https://github.com/ddhe9527/my_toolkit
Email : heduoduo321@163.com

Enjoy and free to use at your own risk~"
}


## Function: Print error message with red color font, then quit with code 1
## $#: 1
## $1: Error message
function error_quit(){
    echo `tput setaf 1; tput bold`"error: "$1`tput sgr0`
    exit 1
}


## Function: Convert Redis version number to nine-digit format
## $#: 1
## $1: Original Redis version number, like 3.2.14, 6.0.9 etc.
## Return: 0 if succeed in parsing, 1 if error occured
function version_format()
{
    if [ $# -ne 1 ]
    then
        echo 'version_format->parameter error'
        return 1
    fi

    if [ `echo $1 | grep -cE '^[1-9][0-9]{0,2}(\.([0-9]|[1-9][0-9]{0,2})){2}$'` -eq 0 ]
    then
        echo 'version_format->unable to parse version string'
        return 1
    fi

    MAJOR_VER='000'`echo $1 | cut -d '.' -f 1`
    let VER_LEN=${#MAJOR_VER}-3
    MAJOR_VER=${MAJOR_VER:$VER_LEN}

    MIDDLE_VER='000'`echo $1 | cut -d '.' -f 2`
    let VER_LEN=${#MIDDLE_VER}-3
    MIDDLE_VER=${MIDDLE_VER:$VER_LEN}

    MINOR_VER='000'`echo $1 | cut -d '.' -f 3`
    let VER_LEN=${#MINOR_VER}-3
    MINOR_VER=${MINOR_VER:$VER_LEN}

    ##Only support redis 3.0.0 and above
    FORMATED_VER="$MAJOR_VER$MIDDLE_VER$MINOR_VER"
    if [[ 10#$FORMATED_VER -lt 10#$LOWEST_VERSION ]]
    then
        echo 'version_format->out of supported version'
        return 1
    fi

    echo $FORMATED_VER
    return 0
}


## Function: Check file's directory exists or not
## $#: 1
## $1: file name with absolute path
## Return: 0 if directory exists, 1 if not
function file_dir_exist_check()
{
    if [ $# -ne 1 ]
    then
        echo 'file_dir_exist_check->parameter error'
        return 1
    fi

    if [ ${1:0:1} != '/' ]
    then
        echo 'file_dir_exist_check->please use absolute path'
        return 1
    fi

    V_DIR=${1%/*}
    if [ ! -d $V_DIR ]
    then
        echo "file_dir_exist_check->$V_DIR directory does not exist"
        return 1
    fi

    return 0
}


## Function: Output a default redis config file for particular version
##           Tested version range: 3.0.0 ~ 6.0.9
## $#: 2
## $1: nine-digit format Redis version, like 003002014, 006000009 etc.
## $2: Output file name
## Return: 0 if it succeed in writing output file, 1 if error occured
function default_redis_config()
{
    if [ $# -ne 2 ]
    then
        echo 'default_redis_config->parameter error'
        return 1
    fi

    RET=$(file_dir_exist_check $2)
    if [ $? -ne 0 ]
    then
        echo 'default_redis_config->'$RET
        return 1
    fi

    VERSION_STR=$1
    TARGET_FILE=$2

    TEMP_FILE="/tmp/"$RANDOM
    RET=$(file_dir_exist_check $TEMP_FILE)
    if [ $? -ne 0 ]
    then
        echo 'default_redis_config->'$RET
        return 1
    fi

    echo '003000000@999999999@# include' > $TEMP_FILE
    echo '004000000@999999999@# loadmodule' >> $TEMP_FILE
    echo '003000000@003000999@# bind' >> $TEMP_FILE
    echo '003002000@999999999@bind 127.0.0.1' >> $TEMP_FILE
    echo '003002000@999999999@protected-mode yes' >> $TEMP_FILE
    echo '003000000@999999999@port 6379' >> $TEMP_FILE
    echo '003000000@999999999@tcp-backlog 511' >> $TEMP_FILE
    echo '003000000@999999999@# unixsocket' >> $TEMP_FILE
    echo '003000000@999999999@# unixsocketperm' >> $TEMP_FILE
    echo '003000000@999999999@timeout 0' >> $TEMP_FILE
    echo '003000000@003002000@tcp-keepalive 0' >> $TEMP_FILE
    echo '003002001@999999999@tcp-keepalive 300' >> $TEMP_FILE
    echo '006000000@999999999@# tls-port' >> $TEMP_FILE
    echo '006000000@999999999@# tls-cert-file' >> $TEMP_FILE
    echo '006000000@999999999@# tls-key-file' >> $TEMP_FILE
    echo '006000000@999999999@# tls-dh-params-file' >> $TEMP_FILE
    echo '006000000@999999999@# tls-ca-cert-file' >> $TEMP_FILE
    echo '006000000@999999999@# tls-ca-cert-dir' >> $TEMP_FILE
    echo '006000000@999999999@# tls-auth-clients' >> $TEMP_FILE
    echo '006000000@999999999@# tls-replication' >> $TEMP_FILE
    echo '006000000@999999999@# tls-cluster' >> $TEMP_FILE
    echo '006000000@999999999@# tls-protocols' >> $TEMP_FILE
    echo '006000000@999999999@# tls-ciphers' >> $TEMP_FILE
    echo '006000000@999999999@# tls-ciphersuites' >> $TEMP_FILE
    echo '006000000@999999999@# tls-prefer-server-ciphers' >> $TEMP_FILE
    echo '006000006@999999999@# tls-session-caching' >> $TEMP_FILE
    echo '006000006@999999999@# tls-session-cache-size' >> $TEMP_FILE
    echo '006000006@999999999@# tls-session-cache-timeout' >> $TEMP_FILE
    echo '003000000@999999999@daemonize no' >> $TEMP_FILE
    echo '003002000@999999999@supervised no' >> $TEMP_FILE
    echo '003000000@003002000@pidfile /var/run/redis.pid' >> $TEMP_FILE
    echo '003002001@999999999@pidfile /var/run/redis_6379.pid' >> $TEMP_FILE
    echo '003000000@999999999@loglevel notice' >> $TEMP_FILE
    echo '003000000@999999999@logfile ""' >> $TEMP_FILE
    echo '003000000@999999999@# syslog-enabled' >> $TEMP_FILE
    echo '003000000@999999999@# syslog-ident' >> $TEMP_FILE
    echo '003000000@999999999@# syslog-facility' >> $TEMP_FILE
    echo '003000000@999999999@databases 16' >> $TEMP_FILE
    echo '004000000@999999999@always-show-logo yes' >> $TEMP_FILE
    echo '003000000@999999999@save 900 1' >> $TEMP_FILE
    echo '003000000@999999999@save 300 10' >> $TEMP_FILE
    echo '003000000@999999999@save 60 10000' >> $TEMP_FILE
    echo '003000000@999999999@stop-writes-on-bgsave-error yes' >> $TEMP_FILE
    echo '003000000@999999999@rdbcompression yes' >> $TEMP_FILE
    echo '003000000@999999999@rdbchecksum yes' >> $TEMP_FILE
    echo '003000000@999999999@dbfilename dump.rdb' >> $TEMP_FILE
    echo '006000000@999999999@rdb-del-sync-files no' >> $TEMP_FILE
    echo '003000000@999999999@dir ./' >> $TEMP_FILE
    echo '003000000@004999999@# slaveof' >> $TEMP_FILE
    echo '005000000@999999999@# replicaof' >> $TEMP_FILE
    echo '003000000@999999999@# masterauth' >> $TEMP_FILE
    echo '006000000@999999999@# masteruser' >> $TEMP_FILE
    echo '003000000@004999999@slave-serve-stale-data yes' >> $TEMP_FILE
    echo '005000000@999999999@replica-serve-stale-data yes' >> $TEMP_FILE
    echo '003000000@004999999@slave-read-only yes' >> $TEMP_FILE
    echo '005000000@999999999@replica-read-only yes' >> $TEMP_FILE
    echo '003000000@999999999@repl-diskless-sync no' >> $TEMP_FILE
    echo '003000000@999999999@repl-diskless-sync-delay 5' >> $TEMP_FILE
    echo '006000000@999999999@repl-diskless-load disabled' >> $TEMP_FILE
    echo '003000000@004999999@# repl-ping-slave-period' >> $TEMP_FILE
    echo '005000000@999999999@# repl-ping-replica-period' >> $TEMP_FILE
    echo '003000000@999999999@# repl-timeout' >> $TEMP_FILE
    echo '003000000@999999999@repl-disable-tcp-nodelay no' >> $TEMP_FILE
    echo '003000000@999999999@# repl-backlog-size' >> $TEMP_FILE
    echo '003000000@999999999@# repl-backlog-ttl' >> $TEMP_FILE
    echo '003000000@004999999@slave-priority 100' >> $TEMP_FILE
    echo '005000000@999999999@replica-priority 100' >> $TEMP_FILE
    echo '003000000@004999999@# min-slaves-to-write' >> $TEMP_FILE
    echo '005000000@999999999@# min-replicas-to-write' >> $TEMP_FILE
    echo '003000000@004999999@# min-slaves-max-lag' >> $TEMP_FILE
    echo '005000000@999999999@# min-replicas-max-lag' >> $TEMP_FILE
    echo '003002002@004999999@# slave-announce-ip' >> $TEMP_FILE
    echo '005000000@999999999@# replica-announce-ip' >> $TEMP_FILE
    echo '003002002@004999999@# slave-announce-port' >> $TEMP_FILE
    echo '005000000@999999999@# replica-announce-port' >> $TEMP_FILE
    echo '006000000@999999999@# tracking-table-max-keys' >> $TEMP_FILE
    echo '006000000@999999999@# user' >> $TEMP_FILE
    echo '006000000@999999999@acllog-max-len 128' >> $TEMP_FILE
    echo '006000000@999999999@# aclfile' >> $TEMP_FILE
    echo '003000000@999999999@# requirepass' >> $TEMP_FILE
    echo '003000000@999999999@# rename-command' >> $TEMP_FILE
    echo '003000000@999999999@# maxclients' >> $TEMP_FILE
    echo '003000000@999999999@# maxmemory' >> $TEMP_FILE
    echo '003000000@999999999@# maxmemory-policy' >> $TEMP_FILE
    echo '003000000@999999999@# maxmemory-samples' >> $TEMP_FILE
    echo '005000000@999999999@# replica-ignore-maxmemory' >> $TEMP_FILE
    echo '006000000@999999999@# active-expire-effort' >> $TEMP_FILE
    echo '004000000@999999999@lazyfree-lazy-eviction no' >> $TEMP_FILE
    echo '004000000@999999999@lazyfree-lazy-expire no' >> $TEMP_FILE
    echo '004000000@999999999@lazyfree-lazy-server-del no' >> $TEMP_FILE
    echo '004000000@004999999@slave-lazy-flush no' >> $TEMP_FILE
    echo '005000000@999999999@replica-lazy-flush no' >> $TEMP_FILE
    echo '006000000@999999999@lazyfree-lazy-user-del no' >> $TEMP_FILE
    echo '006000000@999999999@# io-threads' >> $TEMP_FILE
    echo '006000000@999999999@# io-threads-do-reads' >> $TEMP_FILE
    echo '006000007@999999999@oom-score-adj no' >> $TEMP_FILE
    echo '006000007@999999999@oom-score-adj-values 0 200 800' >> $TEMP_FILE
    echo '003000000@999999999@appendonly no' >> $TEMP_FILE
    echo '003000000@999999999@appendfilename "appendonly.aof"' >> $TEMP_FILE
    echo '003000000@999999999@appendfsync everysec' >> $TEMP_FILE
    echo '003000000@999999999@no-appendfsync-on-rewrite no' >> $TEMP_FILE
    echo '003000000@999999999@auto-aof-rewrite-percentage 100' >> $TEMP_FILE
    echo '003000000@999999999@auto-aof-rewrite-min-size 64mb' >> $TEMP_FILE
    echo '003000000@999999999@aof-load-truncated yes' >> $TEMP_FILE
    echo '004000000@004999999@aof-use-rdb-preamble no' >> $TEMP_FILE
    echo '005000000@999999999@aof-use-rdb-preamble yes' >> $TEMP_FILE
    echo '003000000@999999999@lua-time-limit 5000' >> $TEMP_FILE
    echo '003000000@999999999@# cluster-enabled' >> $TEMP_FILE
    echo '003000000@999999999@# cluster-config-file' >> $TEMP_FILE
    echo '003000000@999999999@# cluster-node-timeout' >> $TEMP_FILE
    echo '003000000@004999999@# cluster-slave-validity-factor' >> $TEMP_FILE
    echo '005000000@999999999@# cluster-replica-validity-factor' >> $TEMP_FILE
    echo '003000000@999999999@# cluster-migration-barrier' >> $TEMP_FILE
    echo '003000000@999999999@# cluster-require-full-coverage' >> $TEMP_FILE
    echo '004000009@004999999@# cluster-slave-no-failover' >> $TEMP_FILE
    echo '005000000@999999999@# cluster-replica-no-failover' >> $TEMP_FILE
    echo '006000000@999999999@# cluster-allow-reads-when-down' >> $TEMP_FILE
    echo '004000000@999999999@# cluster-announce-ip' >> $TEMP_FILE
    echo '004000000@999999999@# cluster-announce-port' >> $TEMP_FILE
    echo '004000000@999999999@# cluster-announce-bus-port' >> $TEMP_FILE
    echo '003000000@999999999@slowlog-log-slower-than 10000' >> $TEMP_FILE
    echo '003000000@999999999@slowlog-max-len 128' >> $TEMP_FILE
    echo '003000000@999999999@latency-monitor-threshold 0' >> $TEMP_FILE
    echo '003000000@999999999@notify-keyspace-events ""' >> $TEMP_FILE
    echo '006000000@999999999@# gopher-enabled' >> $TEMP_FILE
    echo '003000000@999999999@hash-max-ziplist-entries 512' >> $TEMP_FILE
    echo '003000000@999999999@hash-max-ziplist-value 64' >> $TEMP_FILE
    echo '003000000@003000999@list-max-ziplist-entries 512' >> $TEMP_FILE
    echo '003000000@003000999@list-max-ziplist-value 64' >> $TEMP_FILE
    echo '003002000@999999999@list-max-ziplist-size -2' >> $TEMP_FILE
    echo '003002000@999999999@list-compress-depth 0' >> $TEMP_FILE
    echo '003000000@999999999@set-max-intset-entries 512' >> $TEMP_FILE
    echo '003000000@999999999@zset-max-ziplist-entries 128' >> $TEMP_FILE
    echo '003000000@999999999@zset-max-ziplist-value 64' >> $TEMP_FILE
    echo '003000000@999999999@hll-sparse-max-bytes 3000' >> $TEMP_FILE
    echo '005000000@999999999@stream-node-max-bytes 4096' >> $TEMP_FILE
    echo '005000000@999999999@stream-node-max-entries 100' >> $TEMP_FILE
    echo '003000000@999999999@activerehashing yes' >> $TEMP_FILE
    echo '003000000@999999999@client-output-buffer-limit normal 0 0 0' >> $TEMP_FILE
    echo '003000000@004999999@client-output-buffer-limit slave 256mb 64mb 60' >> $TEMP_FILE
    echo '005000000@999999999@client-output-buffer-limit replica 256mb 64mb 60' >> $TEMP_FILE
    echo '003000000@999999999@client-output-buffer-limit pubsub 32mb 8mb 60' >> $TEMP_FILE
    echo '004000007@999999999@# client-query-buffer-limit' >> $TEMP_FILE
    echo '004000007@999999999@# proto-max-bulk-len' >> $TEMP_FILE
    echo '003000000@999999999@hz 10' >> $TEMP_FILE
    echo '005000000@999999999@dynamic-hz yes' >> $TEMP_FILE
    echo '003000000@999999999@aof-rewrite-incremental-fsync yes' >> $TEMP_FILE
    echo '005000000@999999999@rdb-save-incremental-fsync yes' >> $TEMP_FILE
    echo '004000000@999999999@# lfu-log-factor' >> $TEMP_FILE
    echo '004000000@999999999@# lfu-decay-time' >> $TEMP_FILE
    echo '004000000@999999999@# activedefrag' >> $TEMP_FILE
    echo '004000000@999999999@# active-defrag-ignore-bytes' >> $TEMP_FILE
    echo '004000000@999999999@# active-defrag-threshold-lower' >> $TEMP_FILE
    echo '004000000@999999999@# active-defrag-threshold-upper' >> $TEMP_FILE
    echo '004000000@004999999@# active-defrag-cycle-min' >> $TEMP_FILE
    echo '005000000@005999999@# active-defrag-cycle-min' >> $TEMP_FILE
    echo '006000000@999999999@# active-defrag-cycle-min' >> $TEMP_FILE
    echo '004000000@005999999@# active-defrag-cycle-max' >> $TEMP_FILE
    echo '006000000@999999999@# active-defrag-cycle-max' >> $TEMP_FILE
    echo '005000000@999999999@# active-defrag-max-scan-fields' >> $TEMP_FILE
    echo '006000002@999999999@jemalloc-bg-thread yes' >> $TEMP_FILE
    echo '006000002@999999999@# server_cpulist' >> $TEMP_FILE
    echo '006000002@999999999@# bio_cpulist' >> $TEMP_FILE
    echo '006000002@999999999@# aof_rewrite_cpulist' >> $TEMP_FILE
    echo '006000002@999999999@# bgsave_cpulist' >> $TEMP_FILE

    echo "##########################################redis_helper_fingerprint_normal_$VERSION_STR" > $TARGET_FILE
    IFS=$'\n'
    for I in `cat $TEMP_FILE`
    do
        MIN_V=`echo $I | cut -d '@' -f 1`
        MAX_V=`echo $I | cut -d '@' -f 2`
        VAR=${I:20}
        if [[ 10#$VERSION_STR -ge 10#$MIN_V && 10#$VERSION_STR -le 10#$MAX_V ]]
        then
            echo $VAR >> $TARGET_FILE
        fi
    done
    echo "##########################################redis_helper_fingerprint_normal_$VERSION_STR" >> $TARGET_FILE

    /usr/bin/rm -rf $TEMP_FILE
    return 0
}


## Function: Output a default sentinel config file for particular version
##           Tested version range: 3.0.0 ~ 6.0.9
## $#: 2
## $1: nine-digit format Redis version, like 003002014, 006000009 etc.
## $2: Output file name
## Return: 0 if it succeed in writing output file, 1 if error occured
function default_sentinel_config()
{
    if [ $# -ne 2 ]
    then
        echo 'default_sentinel_config->parameter error'
        return 1
    fi

    RET=$(file_dir_exist_check $2)
    if [ $? -ne 0 ]
    then
        echo 'default_sentinel_config->'$RET
        return 1
    fi

    VERSION_STR=$1
    TARGET_FILE=$2

    TEMP_FILE="/tmp/"$RANDOM
    RET=$(file_dir_exist_check $TEMP_FILE)
    if [ $? -ne 0 ]
    then
        echo 'default_sentinel_config->'$RET
        return 1
    fi

    echo '003002004@999999999@# bind' > $TEMP_FILE
    echo '003002004@999999999@# protected-mode' >> $TEMP_FILE
    echo '003000000@999999999@port 26379' >> $TEMP_FILE
    echo '005000000@999999999@daemonize no' >> $TEMP_FILE
    echo '005000000@999999999@pidfile /var/run/redis-sentinel.pid' >> $TEMP_FILE
    echo '005000000@999999999@logfile ""' >> $TEMP_FILE
    echo '003000000@999999999@# sentinel announce-ip' >> $TEMP_FILE
    echo '003000000@999999999@# sentinel announce-port' >> $TEMP_FILE
    echo '003000000@999999999@dir /tmp/' >> $TEMP_FILE
    echo '003000000@999999999@sentinel monitor mymaster 127.0.0.1 6379 2' >> $TEMP_FILE
    echo '003000000@999999999@# sentinel auth-pass' >> $TEMP_FILE
    echo '006000000@999999999@# sentinel auth-user' >> $TEMP_FILE
    echo '003000000@999999999@sentinel down-after-milliseconds mymaster 30000' >> $TEMP_FILE
    echo '006000000@999999999@# requirepass' >> $TEMP_FILE
    echo '003000000@999999999@sentinel parallel-syncs mymaster 1' >> $TEMP_FILE
    echo '003000000@999999999@sentinel failover-timeout mymaster 180000' >> $TEMP_FILE
    echo '003000000@999999999@# sentinel notification-script' >> $TEMP_FILE
    echo '003000000@999999999@# sentinel client-reconfig-script' >> $TEMP_FILE
    echo '003002013@003999999@sentinel deny-scripts-reconfig yes' >> $TEMP_FILE
    echo '004000011@999999999@sentinel deny-scripts-reconfig yes' >> $TEMP_FILE
    echo '005000000@999999999@# SENTINEL rename-command' >> $TEMP_FILE

    echo "##########################################redis_helper_fingerprint_sentinel_$VERSION_STR" > $TARGET_FILE
    IFS=$'\n'
    for I in `cat $TEMP_FILE`
    do
        MIN_V=`echo $I | cut -d '@' -f 1`
        MAX_V=`echo $I | cut -d '@' -f 2`
        VAR=${I:20}
        if [[ 10#$VERSION_STR -ge 10#$MIN_V && 10#$VERSION_STR -le 10#$MAX_V ]]
        then
            echo $VAR >> $TARGET_FILE
        fi
    done
    echo "##########################################redis_helper_fingerprint_sentinel_$VERSION_STR" >> $TARGET_FILE

    /usr/bin/rm -rf $TEMP_FILE
    return 0
}


## Phase options
while getopts "Acd:f:hm:M:o:p:P:r:RsSv:x:" opt
do
    case $opt in
        A)
            SET_AOF_FLAG=1;;
        c)
            SET_CLUSTER_FLAG=1;;
        d)
            SET_DIR_FLAG=1
            DIR=$OPTARG;;
        f)
            SKIP_GENERATE_CNF=1
            CNF_FILE=$OPTARG;;
        h)
            usage
            exit 0;;
        m)
            SET_MEM_FLAG=1
            MEM_USED=$OPTARG;;
        M)
            SET_SENTINEL_MONITOR_FLAG=1
            SENTINEL_MONITOR=$OPTARG;;
        o)
            SET_OUTPUT_FLAG=1
            OUTPUT_FILE=$OPTARG;;
        p)
            SET_PORT_FLAG=1
            PORT=$OPTARG;;
        P)
            SET_PASSWORD_FLAG=1
            PASSWORD=$OPTARG;;
        r)
            SET_REPL_FLAG=1
            REPLOF=$OPTARG;;
        R)
            SET_RDB_FLAG=1;;
        s)
            SENTINEL_FLAG=1;;
        S)
            SETUP_FLAG=1;;
        v)
            SET_VERSION_FLAG=1
            SERVER_VERSION=$OPTARG;;
        x)
            SET_MASTER_PASSWORD_FLAG=1
            MASTER_PASSWORD=$OPTARG;;
        *)
            error_quit "Unknown option, try -h for more information";;
    esac
done

## -v option is mandatory
if [ $SET_VERSION_FLAG -eq 1 ]
then
    RET=$(version_format $SERVER_VERSION)
    if [ $? -ne 0 ]
    then
        error_quit "$RET"
    else
        INTERNAL_SERVER_VERSION=$RET
        echo "Target version: $SERVER_VERSION($INTERNAL_SERVER_VERSION)"
    fi
else
    error_quit "-v option is mandatory, please specify"
fi

## Phase necessary configuration from file
if [ $SKIP_GENERATE_CNF -eq 1 ]
then
    if [ $SETUP_FLAG -eq 1 ]
    then
        if [ -f $CNF_FILE ]
        then
            if [[ `head -1 $CNF_FILE | grep -c redis_helper_fingerprint` -eq 1 && `tail -1 $CNF_FILE | grep -c redis_helper_fingerprint` -eq 1 ]]
            then
                CNF_FILE_HEADER=`head -1 $CNF_FILE`
                CNF_FILE_HEADER_LEN=${#CNF_FILE_HEADER}
                let CNF_FILE_HEADER_LEN=$CNF_FILE_HEADER_LEN-9
                CNF_FILE_VERSION=${CNF_FILE_HEADER:$CNF_FILE_HEADER_LEN}
                if [ "$CNF_FILE_VERSION" != "$INTERNAL_SERVER_VERSION" ]
                then
                    error_quit "There's mismatch version information bewteen -f and -v options"
                fi

                if [ `echo $CNF_FILE_HEADER | grep -c sentinel` -eq 0 ]
                then
                    SENTINEL_FLAG=0
                else
                    SENTINEL_FLAG=1
                fi

                ## port
                if [ `cat $CNF_FILE  | grep -cw ^port` -eq 1 ]
                then
                    PORT=`cat $CNF_FILE | grep -w ^port | awk '{print $2}'`
                else
                    error_quit "Phase 'port' from $CNF_FILE failed"
                fi

                ## dir
                if [ `cat $CNF_FILE  | grep -cw ^dir` -eq 1 ]
                then
                    DIR=`cat $CNF_FILE | grep -w ^dir | awk '{print $2}'`
                else
                    error_quit "Phase 'dir' from $CNF_FILE failed"
                fi

                ## pidfile
                if [ `cat $CNF_FILE  | grep -cw ^pidfile` -eq 1 ]
                then
                    PIDFILE=`cat $CNF_FILE | grep -w ^pidfile | awk '{print $2}'`
                else
                    error_quit "Phase 'pidfile' from $CNF_FILE failed"
                fi

                ## logfile
                if [ `cat $CNF_FILE  | grep -cw ^logfile` -eq 1 ]
                then
                    LOGFILE=`cat $CNF_FILE | grep -w ^logfile | awk '{print $2}'`
                else
                    error_quit "Phase 'logfile' from $CNF_FILE failed"
                fi

                if [ $SENTINEL_FLAG -eq 0 ]
                then
                    ## maxmemory
                    if [ `cat $CNF_FILE | grep -c '^maxmemory '` -eq 1 ]
                    then
                        MEM_USED=`cat $CNF_FILE | grep '^maxmemory ' | awk '{print $2}'`
                    else
                        error_quit "'maxmemory' is recommended for avoiding OOM"
                    fi

                    ## dbfilename
                    if [ `cat $CNF_FILE  | grep -cw ^dbfilename` -eq 1 ]
                    then
                        RDBFILE=`cat $CNF_FILE | grep -w ^dbfilename | awk '{print $2}'`
                    else
                        error_quit "Phase 'dbfilename' from $CNF_FILE failed"
                    fi

                    ## appendfilename
                    if [ `cat $CNF_FILE  | grep -cw ^appendfilename` -eq 1 ]
                    then
                        AOFFILE=`cat $CNF_FILE | grep -w ^appendfilename | awk '{print $2}'`
                    else
                        error_quit "Phase 'appendfilename' from $CNF_FILE failed"
                    fi

                    ## cluster-config-file
                    if [ `cat $CNF_FILE  | grep -cw ^cluster-config-file` -eq 1 ]
                    then
                        CLUSTERFILE=`cat $CNF_FILE | grep -w ^cluster-config-file | awk '{print $2}'`
                    else
                        error_quit "Phase 'cluster-config-file' from $CNF_FILE failed"
                    fi
                fi
            else
                error_quit "$CNF_FILE is broken to be used"
            fi
        else
            error_quit "$CNF_FILE does not exist"
        fi
    else
        echo `tput bold`"Nothing needs to be done."`tput sgr0`
        exit 0
    fi
fi

## Check configuration values
if [[ $SKIP_GENERATE_CNF -eq 1 || $SET_MEM_FLAG -eq 1 ]]
then
    if [ `echo $MEM_USED | grep -cE '^[1-9][0-9]*mb$'` -eq 0 ]
    then
        error_quit "Unrecognized 'maxmemory' value, must be with lowercase 'mb' suffix unit"
    fi
fi

if [[ $SKIP_GENERATE_CNF -eq 1 || $SET_PORT_FLAG -eq 1 ]]
then
    if [ `echo $PORT | grep -cE '^[1-9][0-9]*$'` -eq 0 ]
    then
        error_quit "Unrecognized 'port' value, must be digit"
    fi
fi

if [ $SET_OUTPUT_FLAG -eq 0 ]
then
    if [ $SENTINEL_FLAG -eq 0 ]
    then
        OUTPUT_FILE=$REDIS_CONFIG_FILE
    else
        OUTPUT_FILE=$SENTINEL_CONFIG_FILE
    fi
fi

if [ $SET_REPL_FLAG -eq 1 ]
then
    if [ `echo $REPLOF | grep -cE '^((2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)\.){3}(2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?):[1-9][0-9]*$'` -eq 0 ]
    then
        error_quit "Can not phase -r option to IP:PORT format"
    fi
    MASTER_IP=`echo $REPLOF | cut -d ':' -f 1`
    MASTER_PORT=`echo $REPLOF | cut -d ':' -f 2`
fi

## if it's sentinel, -M option is mandatory
if [[ $SENTINEL_FLAG -eq 1 && $SKIP_GENERATE_CNF -eq 0 ]]
then
    if [ $SET_SENTINEL_MONITOR_FLAG -eq 1 ]
    then
        if [ `echo $SENTINEL_MONITOR | grep -cE '^[a-z|A-Z][a-z|A-Z|0-9]*:((2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)\.){3}(2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?):[1-9][0-9]*:[1-9][0-9]*$'` -eq 1 ]
        then
            SM_NAME=`echo $SENTINEL_MONITOR | cut -d ':' -f 1`
            SM_IP=`echo $SENTINEL_MONITOR | cut -d ':' -f 2`
            SM_PORT=`echo $SENTINEL_MONITOR | cut -d ':' -f 3`
            SM_QUORUM=`echo $SENTINEL_MONITOR | cut -d ':' -f 4`
        else
            error_quit "Can not phase -M option to MASTER_NAME:IP:PORT:QUORUM format"
        fi
    else
        error_quit "-M option is mandatory if -s option is used, please specify"
    fi
fi

## Genarate a configuration file
if [ $SKIP_GENERATE_CNF -eq 0 ]
then
    RET=$(file_dir_exist_check $OUTPUT_FILE)
    if [ $? -eq 1 ]
    then
        error_quit "Check destination of configuration file->$RET"
    else
        if [ -f $OUTPUT_FILE ]
        then
            error_quit "$OUTPUT_FILE already exists, overwriting is unsafe"
        fi
    fi

    if [ $SENTINEL_FLAG -eq 0 ]
    then
        RET=$(default_redis_config $INTERNAL_SERVER_VERSION $OUTPUT_FILE)
    else
        RET=$(default_sentinel_config $INTERNAL_SERVER_VERSION $OUTPUT_FILE)
    fi

    if [ $? -eq 1 ]
    then
        error_quit "Create default configuration file failed->$RET"
    fi

    ## Twist the configuration file

    ## dir
    if [ $SET_DIR_FLAG -eq 1 ]
    then
        DIR_LEN=${#DIR}
        if [ ${DIR:$DIR_LEN-1:1} != '/' ]
        then
            DIR=$DIR'/'
        fi
        sed -i "s|^dir .*|dir $DIR|g" $OUTPUT_FILE
    fi
    DIR=`cat $OUTPUT_FILE | grep -w ^dir | awk '{print $2}'`

    ## port
    if [ $SET_PORT_FLAG -eq 1 ]
    then
        sed -i "s|^port .*|port $PORT|g" $OUTPUT_FILE
    fi
    PORT=`cat $OUTPUT_FILE | grep -w ^port | awk '{print $2}'`

    ## maxmemory
    sed -i "s|^# maxmemory$|maxmemory $MEM_USED|g" $OUTPUT_FILE

    ## maxmemory-policy volatile-ttl
    sed -i "s|^# maxmemory-policy$|maxmemory-policy volatile-ttl|g" $OUTPUT_FILE

    ## bind 0.0.0.0
    sed -i "s|^bind .*|bind 0.0.0.0|g" $OUTPUT_FILE
    sed -i "s|^# bind$|bind 0.0.0.0|g" $OUTPUT_FILE

    ## tcp-keepalive 60
    sed -i "s|^tcp-keepalive .*|tcp-keepalive 60|g" $OUTPUT_FILE

    ## daemonize yes
    sed -i "s|^daemonize .*|daemonize yes|g" $OUTPUT_FILE

    ## pidfile
    PIDFILE=$DIR'redis_'$PORT'.pid'
    sed -i "s|^pidfile .*|pidfile $PIDFILE|g" $OUTPUT_FILE

    ## logfile
    LOGFILE=$DIR'redis_'$PORT'.log'
    sed -i "s|^logfile .*|logfile $LOGFILE|g" $OUTPUT_FILE

    ## save
    if [ $SET_RDB_FLAG -eq 0 ]
    then
        sed -i "s|^save .*|# &|g" $OUTPUT_FILE
    fi

    ## requirepass
    if [ $SET_PASSWORD_FLAG -eq 1 ]
    then
        sed -i "s|# requirepass$|requirepass $PASSWORD|g" $OUTPUT_FILE
    fi

    ## masterauth OR sentinel auth-pass
    if [ $SET_MASTER_PASSWORD_FLAG -eq 1 ]
    then
        sed -i "s|^# masterauth$|masterauth $MASTER_PASSWORD|g" $OUTPUT_FILE
        sed -i "s|^# sentinel auth-pass$|sentinel auth-pass $SM_NAME $MASTER_PASSWORD|g" $OUTPUT_FILE
    fi

    ## dbfilename
    RDBFILE="dump_$PORT.rdb"
    sed -i "s|^dbfilename .*|dbfilename $RDBFILE|g" $OUTPUT_FILE

    ## replicaof/slaveof
    if [ $SET_REPL_FLAG -eq 1 ]
    then
        sed -i "s|^# replicaof$|replicaof $MASTER_IP $MASTER_PORT|g" $OUTPUT_FILE
        sed -i "s|^# slaveof$|slaveof $MASTER_IP $MASTER_PORT|g" $OUTPUT_FILE
    fi

    ## repl-timeout 60
    sed -i "s|^# repl-timeout$|repl-timeout 60|g" $OUTPUT_FILE

    ## repl-backlog-size: 10MB for every 1GB of maxmemory
    TMP_STR=${#MEM_USED}
    TMP_STR=${MEM_USED:0:$TMP_STR-2}
    let TMP_STR=$TMP_STR/100
    TMP_STR=$TMP_STR'mb'
    sed -i "s|^# repl-backlog-size$|repl-backlog-size $TMP_STR|g" $OUTPUT_FILE

    ## repl-backlog-ttl 7200
    sed -i "s|^# repl-backlog-ttl$|repl-backlog-ttl 7200|g" $OUTPUT_FILE

    ## maxclients 10000
    sed -i "s|^# maxclients$|maxclients 10000|g" $OUTPUT_FILE

    ## enable lazyfree
    sed -i "s|^lazyfree-lazy-eviction .*|lazyfree-lazy-eviction yes|g" $OUTPUT_FILE
    sed -i "s|^lazyfree-lazy-expire .*|lazyfree-lazy-expire yes|g" $OUTPUT_FILE
    sed -i "s|^lazyfree-lazy-server-del .*|lazyfree-lazy-server-del yes|g" $OUTPUT_FILE
    sed -i "s|^slave-lazy-flush .*|slave-lazy-flush yes|g" $OUTPUT_FILE
    sed -i "s|^replica-lazy-flush .*|replica-lazy-flush yes|g" $OUTPUT_FILE
    sed -i "s|^lazyfree-lazy-user-del .*|lazyfree-lazy-user-del yes|g" $OUTPUT_FILE

    ## AOF Persistence
    if [ $SET_AOF_FLAG -eq 1 ]
    then
        sed -i "s|^appendonly .*|appendonly yes|g" $OUTPUT_FILE
    fi

    ## appendfilename
    AOFFILE="appendonly_$PORT.aof"
    sed -i "s|^appendfilename .*|appendfilename $AOFFILE|g" $OUTPUT_FILE

    ## no-appendfsync-on-rewrite yes
    sed -i "s|^no-appendfsync-on-rewrite .*|no-appendfsync-on-rewrite yes|g" $OUTPUT_FILE

    ## cluster mode
    if [ $SET_CLUSTER_FLAG -eq 1 ]
    then
        sed -i "s|^# cluster-enabled$|cluster-enabled yes|g" $OUTPUT_FILE
    fi

    ## cluster-config-file
    CLUSTERFILE="cluster_node_$PORT.conf"
    sed -i "s|^# cluster-config-file$|cluster-config-file $CLUSTERFILE|g" $OUTPUT_FILE

    ## cluster-node-timeout 15000
    sed -i "s|^# cluster-node-timeout$|cluster-node-timeout 15000|g" $OUTPUT_FILE

    ## cluster-migration-barrier 1
    sed -i "s|^# cluster-migration-barrier$|cluster-migration-barrier 1|g" $OUTPUT_FILE

    ## cluster-slave-validity-factor/cluster-replica-validity-factor 10
    sed -i "s|^# cluster-replica-validity-factor$|cluster-replica-validity-factor 10|g" $OUTPUT_FILE
    sed -i "s|^# cluster-slave-validity-factor$|cluster-slave-validity-factor 10|g" $OUTPUT_FILE

    ## cluster-require-full-coverage yes
    sed -i "s|^# cluster-require-full-coverage$|cluster-require-full-coverage yes|g" $OUTPUT_FILE

    ## cluster-allow-reads-when-down yes
    sed -i "s|^# cluster-allow-reads-when-down$|cluster-allow-reads-when-down yes|g" $OUTPUT_FILE

    ## client-output-buffer-limit slave/replica 512mb 128mb 60
    sed -i "s|^client-output-buffer-limit slave .*|client-output-buffer-limit slave 512mb 128mb 60|g" $OUTPUT_FILE
    sed -i "s|^client-output-buffer-limit replica .*|client-output-buffer-limit replica 512mb 128mb 60|g" $OUTPUT_FILE

    ## enable activedefrag
    sed -i "s|# activedefrag$|activedefrag yes|g" $OUTPUT_FILE

    ## sentinel monitor MASTER_NAME:IP:PORT:QUORUM
    sed -i "s|^sentinel monitor .*|sentinel monitor $SM_NAME $SM_IP $SM_PORT $SM_QUORUM|g" $OUTPUT_FILE

    ## sentinel down-after-milliseconds MASTER_NAME 60000
    sed -i "s|^sentinel down-after-milliseconds .*|sentinel down-after-milliseconds $SM_NAME 60000|g" $OUTPUT_FILE

    ## sentinel parallel-syncs MASTER_NAME 1
    sed -i "s|^sentinel parallel-syncs .*|sentinel parallel-syncs $SM_NAME 1|g" $OUTPUT_FILE

    ## sentinel failover-timeout MASTER_NAME 180000
    sed -i "s|^sentinel failover-timeout .*|sentinel failover-timeout $SM_NAME 180000|g" $OUTPUT_FILE
fi

if [ $SETUP_FLAG -eq 0 ]
then
    echo `tput bold`"Done!"`tput sgr0`
    exit 0
fi


## Check OS version




## Check dir, port, maxmemory, pidfile, logfile, dbfilename, appendfilename, cluster-config-file before installation
## dir must exist
if [ ! -d $DIR ]
then
    error_quit "$DIR does not exist"
fi

## port must not be occupied
yum install -y net-tools &>/dev/null
if [ $? -ne 0 ]
then
    error_quit "Install net-tools from yum repository failed, please check your yum configuration first"
fi

if [ `netstat -tunlp | awk '{print $4}' | grep -E "*:$PORT$" | wc -l` -gt 0 ]
then
    error_quit "Port $PORT has been occupied, please manually check"
fi

## maxmemory must less than total memory minus 200mb
TMP_STR=${#MEM_USED}
let TMP_STR=$TMP_STR-2
MEM_USED=${MEM_USED:0:$TMP_STR}
if [ $MEM_USED -gt $MEM_CAP ]
then
    error_quit "'maxmemory' is too large for current server"
fi

RDBFILE=$DIR$RDBFILE
AOFFILE=$DIR$AOFFILE
CLUSTERFILE=$DIR$CLUSTERFILE
if [[ -f $PIDFILE || -f $LOGFILE || -f $RDBFILE || -f $AOFFILE || -f $CLUSTERFILE ]]
then
    error_quit "pidfile, logfile, dbfilename, appendfilename, cluster-config-file must not exist"
fi
