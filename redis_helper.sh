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


## Function: Check Redis version number whether it's valid or not
## $#: 1
## $1: Redis version number, like 3.2.14, 6.0.9 etc.
## Return: 0 if it's valid, 1 if not, -1 if error occured
function version_check()
{
    if [ $# -ne 1 ]
    then
        return -1
    fi
    
    
    
}


## Function: Output a default redis config file for particular version
## $#: 2
## $1: Redis version, like 3.2.14, 6.0.9 etc.
## $2: Output file name
## Return: 0 if it succeed in writing output file, -1 if error occured
function default_redis_config()
{
    if [ $# -ne 2 ]
    then
        return -1
    fi
    
    
    
}


## Function: Output a sentinel config file for particular version
## $#: 2
## $1: Redis version, like 3.2.14, 6.0.9 etc.
## $2: Output file name
## Return: 0 if it succeed in writing output file, -1 if error occured
function default_sentinel_config()
{
    if [ $# -ne 2 ]
    then
        return -1
    fi    
    

    
}