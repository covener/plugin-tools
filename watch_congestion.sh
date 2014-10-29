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
  CWND=$(echo $SSOUT | grep cwnd: | sed -r -e 's/.*cwnd:([0-9]+).*/\1/g')
  RTT=$(echo $SSOUT | grep rtt: | sed -r -e 's/.*rtt:([0-9]+).*/\1/g')
  if [ ! -z "$CWND" ]; then
    printf "cwnd=$CWND rtt=$RTT, approx kb given 1500 MSS $(($CWND * 1500 / 1024))kb\n";
  fi
done

