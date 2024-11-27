#!/bin/sh


##############################################################
##  E-mail: heduoduo321@163.com                             ##
##    Date: 2024-11-27                                      ##
##    Info: TDSQL monitoring script for Zabbix integration  ##
##############################################################


IP_ADDR=10.34.3.13
AUTH_KEY=2c605673c860f21f94cd26cb390bf671
CLUSTER_KEY=tdsql_sk3fozaph


## instance metrics(7)
MKEY_LIST_01=("status" "degrade_flag" "mysql_master_switch" "mtime" "rstate" "instance_name" \
              "clientName")

## txsql metrics(30)
MKEY_LIST_02=("alive" "is_restart" "backup_monitor_binlog" "backup_monitor_xtrabckup" \
            "binlog_dir_usage" "data_dir_usage" "connect_usage" "conn_active" \
            "conn_err_save" "cpu_usage" "mem_usage" "io_usage" "iodelay" "process_fh_max" \
            "process_fh_usage" "active_thread_count" "waiting_thread_count" "processlist_slow_sql" \
            "slow_query_rate" "slave_delay" "slave_io_running" "slave_sql_running" "ismaster" \
            "sqlasyn_state" "gtidIsSame" "mtime" "rstate" "cluster_name" "rstate" "set_name")

## proxy metrics(7)
MKEY_LIST_03=("alive" "conn_usage" "proxy_is_restart" "proxy_cpu_usage" "mtime" "rstate" "cluster_name")

## zookeeper metrics(3)
MKEY_LIST_04=("alive" "zk_avg_latency" "mtime")

## scheduler metrics(2)
MKEY_LIST_11=("checkheartbeat" "mtime")

## online ddl metrics(2)
MKEY_LIST_21=("alive" "mtime")


## internal use
DISCOVERY_FLAG=0
MTYPE_NUM=0
MID_NAME=""
ITEM_NAME=""
JQ_STR=""

BASE_DIR=/tmp
WHITELIST_FILE=$BASE_DIR'/tdsql_monitor_whitelist.log'
MKEY_LIST_1_FILE=$BASE_DIR'/tdsql_monitor_file01.log'
MKEY_LIST_2_FILE=$BASE_DIR'/tdsql_monitor_file02.log'
MKEY_LIST_3_FILE=$BASE_DIR'/tdsql_monitor_file03.log'
MKEY_LIST_4_FILE=$BASE_DIR'/tdsql_monitor_file04.log'
MKEY_LIST_11_FILE=$BASE_DIR'/tdsql_monitor_file11.log'
MKEY_LIST_21_FILE=$BASE_DIR'/tdsql_monitor_file21.log'



## phase options
while getopts "dg:m:t:" opt
do
    case $opt in
        d)
            DISCOVERY_FLAG=1;;
        g)
            ITEM_NAME=$OPTARG;;
        m)
            MID_NAME=$OPTARG;;
        t)
            MTYPE_NUM=$OPTARG;;
        *)
            exit -1;;
    esac
done


## test "-t" option
if [ `echo $MTYPE_NUM | sed -n '/^[1-9][0-9]*$/p'` ]
then
    :
else
    echo '-t option must be a digit and greater than 0\n' >&2
    exit -1
fi


## test "curl" and "jq" command
curl --help >/dev/null
if [ $? -ne 0 ]
then
    echo "curl command not found\n" >&2
    exit -1
fi

jq --help >/dev/null
if [ $? -ne 0 ]
then
    echo "jq command not found\n" >&2
    exit -1
fi



## get item's value from JSON file
if [ $DISCOVERY_FLAG -eq 0 ] && [ "$ITEM_NAME" != "" ] && [ "$MID_NAME" != "" ]
then
    JSON_FILE_VAR='MKEY_LIST_'$MTYPE_NUM'_FILE'
    if [ -v $JSON_FILE_VAR ]
    then
        if [ -e ${!JSON_FILE_VAR} ]
        then
            JQ_STR=""
            BLACKLIST=`cat ${!JSON_FILE_VAR} | jq ".data[] | select(.mid == \"$MID_NAME\") | select((.mkey == \"rstate\") and (.mval != \"1\")) | .pmid"`

            if [ `echo "$BLACKLIST" | wc -l` -gt 0 ]
            then
                for i in `echo "$BLACKLIST"`
                do
                    JQ_STR=$JQ_STR" and (.pmid != $i)"
                done
            fi

            VAL=`cat ${!JSON_FILE_VAR} | jq ".data[] | select((.mid == \"$MID_NAME\") and (.mkey == \"$ITEM_NAME\") $JQ_STR) | .mval" | sed 's/^"//g' | sed 's/"$//g'`

            ## if $VAL is datetime(YYYY-MM-DD HH:MM:SS), convert it into unix-timestamp
            if [ `echo $VAL | grep -E '^([0-9]{4})-?(1[0-2]|0[1-9])-?(3[01]|0[1-9]|[12][0-9]) (2[0-3]|[01][0-9]):?([0-5][0-9]):?([0-5][0-9])$' | wc -l` -eq 0 ]
            then
                echo $VAL
            else
                date -d "$VAL" +%s 2>/dev/null

                if [ $? -ne 0 ]
                then
                    echo "datetime convert to unix-timestamp error\n" >&2
                    exit -1
                fi
            fi
        fi

        exit 0
    else
        exit -1 
    fi
fi



## discovery TDSQL objects(mtype=1)
if [ $DISCOVERY_FLAG -eq 1 ] && [ $MTYPE_NUM -eq 1 ]
then
    ## get 'mtype=1' metrics via curl
    MKLIST=""
    for i in ${MKEY_LIST_01[@]};
    do
        if [ "$MKLIST" == "" ]
        then
            MKLIST='"'$i'"'
        else
            MKLIST=$MKLIST',"'$i'"'
        fi
    done

    JSON_STR=""
    JSON_STR=`curl --location --request POST "http://$IP_ADDR/tdsqlpcloud/index.php/api/monitor_data/fetch?auth_key=$AUTH_KEY" --header 'Content-Type: application/json' \
    -d "{\"cluster_key\": \"$CLUSTER_KEY\", \"mtype\": \"1\", \"mkey_list\": [$MKLIST]}"`

    if [ $? -ne 0 ]
    then
        echo "curl mtype=1 failed\n" >&2
        exit -1
    fi

    echo "$JSON_STR" >$MKEY_LIST_1_FILE


    ## generate TDSQL instance whitelist file
    BLACKLIST=""
    if [ `cat $MKEY_LIST_1_FILE | wc -L` -gt 0 ]
    then
        BLACKLIST=`cat $MKEY_LIST_1_FILE | jq '.data[] | select((.mkey == "rstate") and (.mval != "1")) | .mid' | sort | uniq`
    else
        echo "$MKEY_LIST_1_FILE is empty\n" >&2
        exit -1
    fi

    if [ `echo "$BLACKLIST" | wc -l` -gt 0 ]
    then
        JQ_STR=""
        for i in `echo "$BLACKLIST"`
        do
            if [ "$JQ_STR" == "" ]
            then
                JQ_STR="(.mid != $i)"
            else
                JQ_STR=$JQ_STR" and (.mid != $i)"
            fi
        done

        cat $MKEY_LIST_1_FILE | jq ".data[] | select($JQ_STR) | .mid" | sort | uniq >$WHITELIST_FILE
    else
        cat $MKEY_LIST_1_FILE | jq '.data[] | .mid' | sort | uniq >$WHITELIST_FILE
    fi


    ## print JSON string
    if [ -e $WHITELIST_FILE ] && [ `cat $WHITELIST_FILE | wc -l` -gt 0 ]
    then
        IDX=0
        CNT=`cat $WHITELIST_FILE | wc -l`
        echo '{"data":['
        for i in `cat $WHITELIST_FILE`
        do
            echo -n '{"{#INSTANCE_NAME}":'$i'}'
            IDX=`expr $IDX + 1`
            if [ $IDX -lt $CNT ]
            then
                echo ','
            fi
        done
        echo ']}'
    fi

    exit 0
fi



## discovery txsql objects(mtype=2)
if [ $DISCOVERY_FLAG -eq 1 ] && [ $MTYPE_NUM -eq 2 ]
then
    ## get 'mtype=2' metrics via curl
    PMIDLIST=""
    if [ -e $WHITELIST_FILE ] && [ `cat $WHITELIST_FILE | wc -l` -gt 0 ]
    then
        for i in `cat $WHITELIST_FILE`
        do
            if [ "$PMIDLIST" == "" ]
            then
                PMIDLIST=$i
            else
                PMIDLIST=$PMIDLIST','$i
            fi
        done
    else
        exit 0
    fi

    MKLIST=""
    for i in ${MKEY_LIST_02[@]};
    do
        if [ "$MKLIST" == "" ]
        then
            MKLIST='"'$i'"'
        else
            MKLIST=$MKLIST',"'$i'"'
        fi
    done

    JSON_STR=""
    JSON_STR=`curl --location --request POST "http://$IP_ADDR/tdsqlpcloud/index.php/api/monitor_data/fetch?auth_key=$AUTH_KEY" --header 'Content-Type: application/json' \
    -d "{\"cluster_key\": \"$CLUSTER_KEY\", \"mtype\": \"2\", \"mkey_list\": [$MKLIST], \"pmid_list\": [$PMIDLIST]}"`

    if [ $? -ne 0 ]
    then
        echo "curl mtype=2 failed\n" >&2
        exit -1
    fi

    echo "$JSON_STR" >$MKEY_LIST_2_FILE


    ## generate txsql instance whitelist
    JQ_STR=""
    for i in `cat $WHITELIST_FILE`
    do
        if [ "$JQ_STR" == "" ]
        then
            JQ_STR="(.pmid == $i)"
        else
            JQ_STR=$JQ_STR" or (.pmid == $i)"
        fi
    done

    WHITELIST=""
    if [ `cat $MKEY_LIST_2_FILE | wc -L` -gt 0 ]
    then
        WHITELIST=`cat $MKEY_LIST_2_FILE | jq ".data[] | select ($JQ_STR) | .mid" | sort | uniq`
    else
        exit 0
    fi


    ## print JSON string
    if [ `echo "$WHITELIST" | wc -l` -gt 0 ]
    then
        IDX=0
        CNT=`echo "$WHITELIST" | wc -l`
        echo '{"data":['
        for i in `echo "$WHITELIST"`
        do
            echo -n '{"{#TXSQL_NAME}":'$i'}'
            IDX=`expr $IDX + 1`
            if [ $IDX -lt $CNT ]
            then
                echo ','
            fi
        done
        echo ']}'
    fi

    exit 0
fi



## discovery proxy objects(mtype=3)
if [ $DISCOVERY_FLAG -eq 1 ] && [ $MTYPE_NUM -eq 3 ]
then
    ## get 'mtype=3' metrics via curl
    PMIDLIST=""
    if [ -e $WHITELIST_FILE ] && [ `cat $WHITELIST_FILE | wc -l` -gt 0 ]
    then
        for i in `cat $WHITELIST_FILE`
        do
            if [ "$PMIDLIST" == "" ]
            then
                PMIDLIST=$i
            else
                PMIDLIST=$PMIDLIST','$i
            fi
        done
    else
        exit 0
    fi

    MKLIST=""
    for i in ${MKEY_LIST_03[@]};
    do
        if [ "$MKLIST" == "" ]
        then
            MKLIST='"'$i'"'
        else
            MKLIST=$MKLIST',"'$i'"'
        fi
    done

    JSON_STR=""
    JSON_STR=`curl --location --request POST "http://$IP_ADDR/tdsqlpcloud/index.php/api/monitor_data/fetch?auth_key=$AUTH_KEY" --header 'Content-Type: application/json' \
    -d "{\"cluster_key\": \"$CLUSTER_KEY\", \"mtype\": \"3\", \"mkey_list\": [$MKLIST], \"pmid_list\": [$PMIDLIST]}"`

    if [ $? -ne 0 ]
    then
        echo "curl mtype=3 failed\n" >&2
        exit -1
    fi

    echo "$JSON_STR" >$MKEY_LIST_3_FILE


    ## generate proxy instance whitelist
    JQ_STR=""
    for i in `cat $WHITELIST_FILE`
    do
        if [ "$JQ_STR" == "" ]
        then
            JQ_STR="(.pmid == $i)"
        else
            JQ_STR=$JQ_STR" or (.pmid == $i)"
        fi
    done

    WHITELIST=""
    if [ `cat $MKEY_LIST_3_FILE | wc -L` -gt 0 ]
    then
        WHITELIST=`cat $MKEY_LIST_3_FILE | jq ".data[] | select ($JQ_STR) | .mid" | sort | uniq`
    else
        exit 0
    fi


    ## print JSON string
    if [ `echo "$WHITELIST" | wc -l` -gt 0 ]
    then
        IDX=0
        CNT=`echo "$WHITELIST" | wc -l`
        echo '{"data":['
        for i in `echo "$WHITELIST"`
        do
            echo -n '{"{#PROXY_NAME}":'$i'}'
            IDX=`expr $IDX + 1`
            if [ $IDX -lt $CNT ]
            then
                echo ','
            fi
        done
        echo ']}'
    fi

    exit 0
fi



## discovery zookeeper objects(mtype=4)
if [ $DISCOVERY_FLAG -eq 1 ] && [ $MTYPE_NUM -eq 4 ]
then
    ## get 'mtype=4' metrics via curl
    MKLIST=""
    for i in ${MKEY_LIST_04[@]};
    do
        if [ "$MKLIST" == "" ]
        then
            MKLIST='"'$i'"'
        else
            MKLIST=$MKLIST',"'$i'"'
        fi
    done

    JSON_STR=""
    JSON_STR=`curl --location --request POST "http://$IP_ADDR/tdsqlpcloud/index.php/api/monitor_data/fetch?auth_key=$AUTH_KEY" --header 'Content-Type: application/json' \
    -d "{\"cluster_key\": \"$CLUSTER_KEY\", \"mtype\": \"4\", \"mkey_list\": [$MKLIST]}"`

    if [ $? -ne 0 ]
    then
        echo "curl mtype=4 failed\n" >&2
        exit -1
    fi

    echo "$JSON_STR" >$MKEY_LIST_4_FILE


    ## print JSON string
    WHITELIST=""
    if [ `cat $MKEY_LIST_4_FILE | wc -L` -gt 0 ]
    then
        WHITELIST=`cat $MKEY_LIST_4_FILE | jq ".data[] | .mid" | sort | uniq`
    else
        exit 0
    fi

    if [ `echo "$WHITELIST" | wc -l` -gt 0 ]
    then
        IDX=0
        CNT=`echo "$WHITELIST" | wc -l`
        echo '{"data":['
        for i in `echo "$WHITELIST"`
        do
            echo -n '{"{#ZKNODE_NAME}":'$i'}'
            IDX=`expr $IDX + 1`
            if [ $IDX -lt $CNT ]
            then
                echo ','
            fi
        done
        echo ']}'
    fi

    exit 0
fi



## discovery scheduler objects(mtype=11)
if [ $DISCOVERY_FLAG -eq 1 ] && [ $MTYPE_NUM -eq 11 ]
then
    ## get 'mtype=11' metrics via curl
    MKLIST=""
    for i in ${MKEY_LIST_11[@]};
    do
        if [ "$MKLIST" == "" ]
        then
            MKLIST='"'$i'"'
        else
            MKLIST=$MKLIST',"'$i'"'
        fi
    done

    JSON_STR=""
    JSON_STR=`curl --location --request POST "http://$IP_ADDR/tdsqlpcloud/index.php/api/monitor_data/fetch?auth_key=$AUTH_KEY" --header 'Content-Type: application/json' \
    -d "{\"cluster_key\": \"$CLUSTER_KEY\", \"mtype\": \"11\", \"mkey_list\": [$MKLIST]}"`

    if [ $? -ne 0 ]
    then
        echo "curl mtype=11 failed\n" >&2
        exit -1
    fi

    echo "$JSON_STR" >$MKEY_LIST_11_FILE


    ## print JSON string
    WHITELIST=""
    if [ `cat $MKEY_LIST_11_FILE | wc -L` -gt 0 ]
    then
        WHITELIST=`cat $MKEY_LIST_11_FILE | jq ".data[] | .mid" | sort | uniq`
    else
        exit 0
    fi

    if [ `echo "$WHITELIST" | wc -l` -gt 0 ]
    then
        IDX=0
        CNT=`echo "$WHITELIST" | wc -l`
        echo '{"data":['
        for i in `echo "$WHITELIST"`
        do
            echo -n '{"{#SCHEDULER_NAME}":'$i'}'
            IDX=`expr $IDX + 1`
            if [ $IDX -lt $CNT ]
            then
                echo ','
            fi
        done
        echo ']}'
    fi

    exit 0
fi



## discovery online ddl objects(mtype=21)
if [ $DISCOVERY_FLAG -eq 1 ] && [ $MTYPE_NUM -eq 21 ]
then
    ## get 'mtype=21' metrics via curl
    MKLIST=""
    for i in ${MKEY_LIST_21[@]};
    do
        if [ "$MKLIST" == "" ]
        then
            MKLIST='"'$i'"'
        else
            MKLIST=$MKLIST',"'$i'"'
        fi
    done

    JSON_STR=""
    JSON_STR=`curl --location --request POST "http://$IP_ADDR/tdsqlpcloud/index.php/api/monitor_data/fetch?auth_key=$AUTH_KEY" --header 'Content-Type: application/json' \
    -d "{\"cluster_key\": \"$CLUSTER_KEY\", \"mtype\": \"21\", \"mkey_list\": [$MKLIST]}"`

    if [ $? -ne 0 ]
    then
        echo "curl mtype=21 failed\n" >&2
        exit -1
    fi

    echo "$JSON_STR" >$MKEY_LIST_21_FILE


    ## print JSON string
    WHITELIST=""
    if [ `cat $MKEY_LIST_21_FILE | wc -L` -gt 0 ]
    then
        WHITELIST=`cat $MKEY_LIST_21_FILE | jq ".data[] | .mid" | sort | uniq`
    else
        exit 0
    fi

    if [ `echo "$WHITELIST" | wc -l` -gt 0 ]
    then
        IDX=0
        CNT=`echo "$WHITELIST" | wc -l`
        echo '{"data":['
        for i in `echo "$WHITELIST"`
        do
            echo -n '{"{#ONLINEDDL_NAME}":'$i'}'
            IDX=`expr $IDX + 1`
            if [ $IDX -lt $CNT ]
            then
                echo ','
            fi
        done
        echo ']}'
    fi

    exit 0
fi
