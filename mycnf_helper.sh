#!/bin/bash

echo '
Usage:
======================================================================================
-a: <flag>   Automatically gets CPU core count and memory capacity from current server
-c: <number> Logical CPU core count
-m: <number> Memory capacity(Unit: GB)
-o: <string> Destination of MySQL config file(Default: $PWD/my.cnf)
-p: <number> Port(Default: 3306)
-s: <flag>   Setup the MySQL Server
-v: <string> MySQL Server version. eg: 5.6.32, 5.7.22, 8.0.18
======================================================================================
'

MY_CNF=$PWD/my.cnf
MY_PORT=3306

## Phase the argument
while getopts "ac:m:o:p:sv:" opt
do
    case $opt in
        a)
            CPU_CORE_COUNT=`cat /proc/cpuinfo| grep "processor"| wc -l`
            MEM_CAP=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
            let MEM_CAP=$MEM_CAP/1024/1024;;
        c)
            CPU_CORE_COUNT=$OPTARG;;
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
            echo "Unknown argument, quit"
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
    echo "MySQL Server Port: "$MY_PORT
else
    echo "Invalid port number, use -p to specify"
    exit 1
fi

## Check target MySQL Server version
MYSQL_VERSION=`echo $SERVER_VERSION | sed "s/\.//2g" | sed "s/\./0/g"`
if [ `echo $MYSQL_VERSION | sed -n '/^[1-9][0-9]*$/p'` ]
then
    echo "MySQL Server version: "$SERVER_VERSION\($MYSQL_VERSION\)
else
    echo "Invalid MySQL Server version, use -v to specify"
    exit 1
fi

## Check the destination of my.cnf
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
        ##echo "MySQL config file created: "$MY_CNF
        :
    fi
fi


















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
