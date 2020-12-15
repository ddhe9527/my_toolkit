#!/bin/bash

REDISCLI=/usr/local/bin/redis-cli
HOSTNAME=127.0.0.1
PORT=6379
PASS=''
USER=default
TEMP_FILE=/tmp/zbx_redis$RANDOM$RANDOM.log

function clear_quit()
{
    if [ -f $TEMP_FILE ]
    then
        rm -rf $TEMP_FILE &>/dev/null
    fi
    exit $1
}

if [ $# -lt 1 ]
then
    ## Exit 1 if missing argument
    exit 1
fi

if [ -f $REDISCLI ]
then
    ## Exit 3 if redis-cli -v command error
    VER=`$REDISCLI -v 2>/dev/null` || exit 3

    VER=`echo $VER | awk '{print $2}'`
    MAJOR_VER=${VER%%.*}

    ## Exit 4 if major version is not digit
    expr $MAJOR_VER + 0 &>/dev/null || exit 4
else
    ## Exit 2 if redis-cli dose not exists
    exit 2
fi

if [[ $PASS = '' && $USER = 'default' ]]
then
    CMD="$REDISCLI -h $HOSTNAME -p $PORT "
elif [[ $PASS != '' && $USER = 'default' ]]
then
    CMD="$REDISCLI -h $HOSTNAME -p $PORT -a '$PASS' "
elif [[ $PASS != '' && $USER != 'default' && $MAJOR_VER -ge 6 ]]
then
    ## Redis 6.0 new feature: ACL
    CMD="$REDISCLI -h $HOSTNAME -p $PORT --user $USER -a '$PASS' "
else
    ## Exit 5 because of --user option was not supported in Redis 5.x and below
    exit 5
fi

case $1 in
PING)
    CMD=$CMD'PING'
    RESULT=`eval $CMD 2>/dev/null` || exit 7
    echo $RESULT
    ;;
CLUSTER)
    CMD=$CMD'CLUSTER INFO'
    RESULT=`eval $CMD | grep cluster_state 2>/dev/null` || exit 14
    echo $RESULT | cut -d ':' -f 2
    ;;
SLOWLOG)
    CMD_TMP=$CMD'CONFIG GET slowlog-max-len'
    SLOWLOG_MAX_LEN=`eval $CMD_TMP 2>/dev/null` || exit 8
    SLOWLOG_MAX_LEN=`echo $SLOWLOG_MAX_LEN | cut -d ' ' -f 2`
    CMD=$CMD'SLOWLOG GET $SLOWLOG_MAX_LEN'
    
    eval $CMD 1>$TEMP_FILE 2>/dev/null
    if [ $? -ne 0 ]
    then
        clear_quit 9
    fi

    UNIX_NOW=`date +%s`
    FIVE_MIN_BEFORE=`expr $UNIX_NOW - 300`
    UPPER_BOUND=`expr $UNIX_NOW + 60`
    CNT=0

    for LINE in `cat $TEMP_FILE`
    do
        if [[ `echo $LINE | grep -E '^[1-9][0-9]*$'` != '' ]]
        then
            if [[ $LINE -gt $FIVE_MIN_BEFORE && $LINE -lt $UPPER_BOUND ]]
            then
                CNT=`expr $CNT + 1`
            fi
        fi
    done
    echo $CNT
    ;;
INFO)
    if [ $# -ne 2 ]
    then
        exit 10
    fi

    CMD=$CMD'INFO'
    eval $CMD 1>$TEMP_FILE 2>/dev/null
    if [ $? -ne 0 ]
    then
        clear_quit 11
    fi

    RESULT=`cat $TEMP_FILE | grep -v '^#' | grep -w $2 | cut -d ':' -f 2 | head -1`
    if [[ $RESULT = '' ]]
    then
        clear_quit 12
    fi
    echo $RESULT
    ;;
CONFIG)
    CMD=$CMD'CONFIG GET "*"'
    eval $CMD 1>$TEMP_FILE 2>/dev/null
    if [ $? -ne 0 ]
    then
        clear_quit 13
    fi

    RESULT=`md5sum $TEMP_FILE | cut -d ' ' -f 1`
    echo $RESULT ## Return a MD5 message
    ;;
PROCESS)
    RESULT=`ps -ef | grep -v grep | grep -w $PORT | grep -cE 'redis-server|redis-sentinel'`
    echo $RESULT
    ;;
*) exit 6;; ## Exit 6 if command is not PING, SLOWLOG, INFO, PROCESS or CONFIG
esac

clear_quit 0
