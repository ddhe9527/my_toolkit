#!/bin/sh

## Default values



## Flags(internal use)



## Function: -h option, print help information and exit 0
function usage()
{
echo '


Github: https://github.com/ddhe9527/my_toolkit
Email : heduoduo321@163.com

Enjoy and free to use at your own risk~'
}

## Function: Print error message with red color font, then quit with code 1
## $#: 1
## $1: Error message
function error_quit(){
    echo `tput setaf 1; tput bold`"Error: "$1`tput sgr0`
    exit 1
}


## Function: Convert Redis version number to nine-digit format
## $#: 1
## $1: Original Redis version number, like 3.2.14, 6.0.9 etc.
## Return: nine-digit format version number, '000000000' if error occured
function version_format()
{
    if [ $# -ne 1 ]
    then
        echo "000000000"
        return 1
    fi

    if [ `echo $1 | grep -E '^[1-9][0-9]{0,2}(\.([0-9]|[1-9][0-9]{0,2})){2}$' | wc -l` -eq 0 ]
    then
        echo "000000000"
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
    
    echo "$MAJOR_VER$MIDDLE_VER$MINOR_VER"
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
        echo 'file_dir_exist_check: Parameter error'
        return 1
    fi

    if [ ${1:0:1} != '/' ]
    then
        echo 'file_dir_exist_check: Please use absolute path'
        return 1
    fi

    DIR=${1%/*}
    if [ ! -d $DIR ]
    then
        echo 'file_dir_exist_check: Directory does not exists'
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
        echo 'default_redis_config: Parameter error'
        return 1
    fi

    RET=$(file_dir_exist_check $2)
    if [ $? -ne 0 ]
    then
        echo 'default_redis_config: '$RET
        return 1
    fi

    VERSION_STR=$1
    if [ $VERSION_STR -lt 003000000 ]
    then
        echo 'default_redis_config: Out of supported version'
        return 1
    fi

    TARGET_FILE=$2
    TEMP_FILE="/tmp/"$RANDOM

    echo '003000000@999999999@include' > $TEMP_FILE
    echo '004000000@999999999@loadmodule' >> $TEMP_FILE
    echo '003000000@003000999@bind' >> $TEMP_FILE
    echo '003002000@999999999@bind' >> $TEMP_FILE
    echo '003002000@999999999@protected-mode' >> $TEMP_FILE
    echo '003000000@999999999@port' >> $TEMP_FILE
    echo '003000000@999999999@tcp-backlog' >> $TEMP_FILE
    echo '003000000@999999999@unixsocket' >> $TEMP_FILE
    echo '003000000@999999999@unixsocketperm' >> $TEMP_FILE
    echo '003000000@999999999@timeout' >> $TEMP_FILE
    echo '003000000@003002000@tcp-keepalive' >> $TEMP_FILE
    echo '003002001@999999999@tcp-keepalive' >> $TEMP_FILE
    echo '006000000@999999999@tls-port' >> $TEMP_FILE
    echo '006000000@999999999@tls-cert-file' >> $TEMP_FILE
    echo '006000000@999999999@tls-key-file' >> $TEMP_FILE
    echo '006000000@999999999@tls-dh-params-file' >> $TEMP_FILE
    echo '006000000@999999999@tls-ca-cert-file' >> $TEMP_FILE
    echo '006000000@999999999@tls-ca-cert-dir' >> $TEMP_FILE
    echo '006000000@999999999@tls-auth-clients' >> $TEMP_FILE
    echo '006000000@999999999@tls-replication' >> $TEMP_FILE
    echo '006000000@999999999@tls-cluster' >> $TEMP_FILE
    echo '006000000@999999999@tls-protocols' >> $TEMP_FILE
    echo '006000000@999999999@tls-ciphers' >> $TEMP_FILE
    echo '006000000@999999999@tls-ciphersuites' >> $TEMP_FILE
    echo '006000000@999999999@tls-prefer-server-ciphers' >> $TEMP_FILE
    echo '006000006@999999999@tls-session-caching' >> $TEMP_FILE
    echo '006000006@999999999@tls-session-cache-size' >> $TEMP_FILE
    echo '006000006@999999999@tls-session-cache-timeout' >> $TEMP_FILE
    echo '003000000@999999999@daemonize' >> $TEMP_FILE
    echo '003002000@999999999@supervised' >> $TEMP_FILE
    echo '003000000@999999999@pidfile' >> $TEMP_FILE
    echo '003000000@999999999@loglevel' >> $TEMP_FILE
    echo '003000000@999999999@logfile' >> $TEMP_FILE
    echo '003000000@999999999@syslog-enabled' >> $TEMP_FILE
    echo '003000000@999999999@syslog-ident' >> $TEMP_FILE
    echo '003000000@999999999@syslog-facility' >> $TEMP_FILE
    echo '003000000@999999999@databases' >> $TEMP_FILE
    echo '004000000@999999999@always-show-logo' >> $TEMP_FILE
    echo '003000000@999999999@save' >> $TEMP_FILE
    echo '003000000@999999999@save' >> $TEMP_FILE
    echo '003000000@999999999@save' >> $TEMP_FILE
    echo '003000000@999999999@stop-writes-on-bgsave-error' >> $TEMP_FILE
    echo '003000000@999999999@rdbcompression' >> $TEMP_FILE
    echo '003000000@999999999@rdbchecksum' >> $TEMP_FILE
    echo '003000000@999999999@dbfilename' >> $TEMP_FILE
    echo '003000000@999999999@dir' >> $TEMP_FILE
    echo '006000000@999999999@rdb-del-sync-files' >> $TEMP_FILE
    echo '003000000@004999999@slaveof' >> $TEMP_FILE
    echo '005000000@999999999@replicaof' >> $TEMP_FILE
    echo '003000000@999999999@masterauth' >> $TEMP_FILE
    echo '006000000@999999999@masteruser' >> $TEMP_FILE
    echo '003000000@004999999@slave-serve-stale-data' >> $TEMP_FILE
    echo '005000000@999999999@replica-serve-stale-data' >> $TEMP_FILE
    echo '003000000@004999999@slave-read-only' >> $TEMP_FILE
    echo '005000000@999999999@replica-read-only' >> $TEMP_FILE
    echo '003000000@999999999@repl-diskless-sync' >> $TEMP_FILE
    echo '003000000@999999999@repl-diskless-sync-delay' >> $TEMP_FILE
    echo '006000000@999999999@repl-diskless-load' >> $TEMP_FILE
    echo '003000000@004999999@repl-ping-slave-period' >> $TEMP_FILE
    echo '005000000@999999999@repl-ping-replica-period' >> $TEMP_FILE
    echo '003000000@999999999@repl-timeout' >> $TEMP_FILE
    echo '003000000@999999999@repl-disable-tcp-nodelay' >> $TEMP_FILE
    echo '003000000@999999999@repl-backlog-size' >> $TEMP_FILE
    echo '003000000@999999999@repl-backlog-ttl' >> $TEMP_FILE
    echo '003000000@004999999@slave-priority' >> $TEMP_FILE
    echo '005000000@999999999@replica-priority' >> $TEMP_FILE
    echo '003000000@004999999@min-slaves-to-write' >> $TEMP_FILE
    echo '005000000@999999999@min-replicas-to-write' >> $TEMP_FILE
    echo '003000000@004999999@min-slaves-max-lag' >> $TEMP_FILE
    echo '005000000@999999999@min-replicas-max-lag' >> $TEMP_FILE
    echo '003002002@004999999@slave-announce-ip' >> $TEMP_FILE
    echo '005000000@999999999@replica-announce-ip' >> $TEMP_FILE
    echo '003002002@004999999@slave-announce-port' >> $TEMP_FILE
    echo '005000000@999999999@replica-announce-port' >> $TEMP_FILE
    echo '006000000@999999999@tracking-table-max-keys' >> $TEMP_FILE
    echo '006000000@999999999@user' >> $TEMP_FILE
    echo '006000000@999999999@acllog-max-len' >> $TEMP_FILE
    echo '006000000@999999999@aclfile' >> $TEMP_FILE
    echo '003000000@999999999@requirepass' >> $TEMP_FILE
    echo '003000000@999999999@rename-command' >> $TEMP_FILE
    echo '003000000@999999999@maxclients' >> $TEMP_FILE
    echo '003000000@999999999@maxmemory' >> $TEMP_FILE
    echo '003000000@999999999@maxmemory-policy' >> $TEMP_FILE
    echo '003000000@999999999@maxmemory-samples' >> $TEMP_FILE
    echo '005000000@999999999@replica-ignore-maxmemory' >> $TEMP_FILE
    echo '006000000@999999999@active-expire-effort' >> $TEMP_FILE
    echo '004000000@999999999@lazyfree-lazy-eviction' >> $TEMP_FILE
    echo '004000000@999999999@lazyfree-lazy-expire' >> $TEMP_FILE
    echo '004000000@999999999@lazyfree-lazy-server-del' >> $TEMP_FILE
    echo '004000000@004999999@slave-lazy-flush' >> $TEMP_FILE
    echo '005000000@999999999@replica-lazy-flush' >> $TEMP_FILE
    echo '006000000@999999999@lazyfree-lazy-user-del' >> $TEMP_FILE
    echo '006000000@999999999@io-threads' >> $TEMP_FILE
    echo '006000000@999999999@io-threads-do-reads' >> $TEMP_FILE
    echo '006000007@999999999@oom-score-adj' >> $TEMP_FILE
    echo '006000007@999999999@oom-score-adj-values' >> $TEMP_FILE
    echo '003000000@999999999@appendonly' >> $TEMP_FILE
    echo '003000000@999999999@appendfilename' >> $TEMP_FILE
    echo '003000000@999999999@appendfsync' >> $TEMP_FILE
    echo '003000000@999999999@no-appendfsync-on-rewrite' >> $TEMP_FILE
    echo '003000000@999999999@auto-aof-rewrite-percentage' >> $TEMP_FILE
    echo '003000000@999999999@auto-aof-rewrite-min-size' >> $TEMP_FILE
    echo '003000000@999999999@aof-load-truncated' >> $TEMP_FILE
    echo '004000000@004999999@aof-use-rdb-preamble' >> $TEMP_FILE
    echo '005000000@999999999@aof-use-rdb-preamble' >> $TEMP_FILE
    echo '003000000@999999999@lua-time-limit' >> $TEMP_FILE
    echo '003000000@999999999@cluster-enabled' >> $TEMP_FILE
    echo '003000000@999999999@cluster-config-file' >> $TEMP_FILE
    echo '003000000@999999999@cluster-node-timeout' >> $TEMP_FILE
    echo '003000000@004999999@cluster-slave-validity-factor' >> $TEMP_FILE
    echo '005000000@999999999@cluster-replica-validity-factor' >> $TEMP_FILE
    echo '003000000@999999999@cluster-migration-barrier' >> $TEMP_FILE
    echo '003000000@999999999@cluster-require-full-coverage' >> $TEMP_FILE
    echo '004000009@004999999@cluster-slave-no-failover' >> $TEMP_FILE
    echo '005000000@999999999@cluster-replica-no-failover' >> $TEMP_FILE
    echo '006000000@999999999@cluster-allow-reads-when-down' >> $TEMP_FILE
    echo '004000000@999999999@cluster-announce-ip' >> $TEMP_FILE
    echo '004000000@999999999@cluster-announce-port' >> $TEMP_FILE
    echo '004000000@999999999@cluster-announce-bus-port' >> $TEMP_FILE
    echo '003000000@999999999@slowlog-log-slower-than' >> $TEMP_FILE
    echo '003000000@999999999@slowlog-max-len' >> $TEMP_FILE
    echo '003000000@999999999@latency-monitor-threshold' >> $TEMP_FILE
    echo '003000000@999999999@notify-keyspace-events' >> $TEMP_FILE
    echo '006000000@999999999@gopher-enabled' >> $TEMP_FILE
    echo '003000000@999999999@hash-max-ziplist-entries' >> $TEMP_FILE
    echo '003000000@999999999@hash-max-ziplist-value' >> $TEMP_FILE
    echo '003000000@003000999@list-max-ziplist-entries' >> $TEMP_FILE
    echo '003000000@003000999@list-max-ziplist-value' >> $TEMP_FILE
    echo '003002000@999999999@list-max-ziplist-size' >> $TEMP_FILE
    echo '003002000@999999999@list-compress-depth' >> $TEMP_FILE
    echo '003000000@999999999@set-max-intset-entries' >> $TEMP_FILE
    echo '003000000@999999999@zset-max-ziplist-entries' >> $TEMP_FILE
    echo '003000000@999999999@zset-max-ziplist-value' >> $TEMP_FILE
    echo '003000000@999999999@hll-sparse-max-bytes' >> $TEMP_FILE
    echo '005000000@999999999@stream-node-max-bytes' >> $TEMP_FILE
    echo '005000000@999999999@stream-node-max-entries' >> $TEMP_FILE
    echo '003000000@999999999@activerehashing' >> $TEMP_FILE
    echo '003000000@999999999@client-output-buffer-limit' >> $TEMP_FILE
    echo '003000000@004999999@client-output-buffer-limit' >> $TEMP_FILE
    echo '005000000@999999999@client-output-buffer-limit' >> $TEMP_FILE
    echo '003000000@999999999@client-output-buffer-limit' >> $TEMP_FILE
    echo '004000007@999999999@client-query-buffer-limit' >> $TEMP_FILE
    echo '004000007@999999999@proto-max-bulk-len' >> $TEMP_FILE
    echo '003000000@999999999@hz' >> $TEMP_FILE
    echo '005000000@999999999@dynamic-hz' >> $TEMP_FILE
    echo '003000000@999999999@aof-rewrite-incremental-fsync' >> $TEMP_FILE
    echo '005000000@999999999@rdb-save-incremental-fsync' >> $TEMP_FILE
    echo '004000000@999999999@lfu-log-factor' >> $TEMP_FILE
    echo '004000000@999999999@lfu-decay-time' >> $TEMP_FILE
    echo '004000000@999999999@activedefrag' >> $TEMP_FILE
    echo '004000000@999999999@active-defrag-ignore-bytes' >> $TEMP_FILE
    echo '004000000@999999999@active-defrag-threshold-lower' >> $TEMP_FILE
    echo '004000000@999999999@active-defrag-threshold-upper' >> $TEMP_FILE
    echo '004000000@004999999@active-defrag-cycle-min' >> $TEMP_FILE
    echo '005000000@005999999@active-defrag-cycle-min' >> $TEMP_FILE
    echo '006000000@999999999@active-defrag-cycle-min' >> $TEMP_FILE
    echo '004000000@005999999@active-defrag-cycle-max' >> $TEMP_FILE
    echo '006000000@999999999@active-defrag-cycle-max' >> $TEMP_FILE
    echo '005000000@999999999@active-defrag-max-scan-fields' >> $TEMP_FILE
    echo '006000002@999999999@jemalloc-bg-thread' >> $TEMP_FILE
    echo '006000002@999999999@server_cpulist' >> $TEMP_FILE
    echo '006000002@999999999@bio_cpulist' >> $TEMP_FILE
    echo '006000002@999999999@aof_rewrite_cpulist' >> $TEMP_FILE
    echo '006000002@999999999@bgsave_cpulist' >> $TEMP_FILE



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
        return 1
    fi    
    

    
}