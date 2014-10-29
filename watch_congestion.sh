#!/bin/bash

if [ $# -ne 1 ]; then
  echo "$0 ip:port"
  exit 1
fi

/sbin/ip route
/sbin/sysctl -a|grep congest
/sbin/ifconfig -a

while true; do 
  sleep .05 
  SSOUT=$(ss -teino state ESTABLISHED | grep -A1 "$1")
  CWNDETC=$(echo $SSOUT | grep cwnd: | sed -r -e 's/.*(rto.*) cwnd:([0-9]+) (.*)/\2 \1 \3/g')
  CWND=$(echo $SSOUT | grep cwnd: | sed -r -e 's/.*(rto.*) cwnd:([0-9]+) .*/\2/g')
  CWNDETC=`echo $CWNDETC|sed -r -e 's/(rtt:[0-9]+)(\S)*/\1/g'`
  if [ ! -z "$CWNDETC" ]; then
    printf "$CWNDETC ;  approx kb given 1500 MSS $(($CWND * 1500 / 1024))kb\n";
  fi
done

