#!/bin/bash

echo '
Usage:
================================================================
-c: <number> Logical CPU core count
-m: <number> Memory capacity, unit is GB
-v: <string> MySQL Server version. eg: 5.6.32, 5.7.22, 8.0.18
-p: <number> port
-o: <string> Output of MySQL config file, default is $PWD/my.cnf
-s: <flag>   Only generate my.cnf file, skip installation
================================================================
'

## Phase the argument
while getopts "c:m:g" opt
do
    case $opt in
        c)
            CPU_CORE_COUNT=$OPTARG;;
        m)
            MEM_CAP=$OPTARG;;
        s)
            SKIP_INSTALLATION=1;;
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














if [[ $SKIP_INSTALLATION -eq 1 ]]
then
	echo "done!"
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
