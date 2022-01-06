#! /bin/bash
URL="localhost:8443"
if [[ $# -gt 0 ]] 
then
    URL=$1
fi;

CODE=`curl  -o /dev/null -w "%{http_code}" https://$1 -k 2> /dev/null`
echo "$1 Responded with code: $CODE"
if [[ $CODE -ne "200" ]] 
then
    exit 2
else
    exit 0
fi;