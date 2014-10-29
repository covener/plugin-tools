#!/bin/bash

if [ $# -ne 1 ]; then
  echo "$0 ip:port"
  exit 1
fi

set -e 

ip route
while true; do 
  sleep .05 
  CWND=$(ss -teino state ESTABLISHED | grep -A1 "$1" | grep cwnd: | sed -r -e 's/.*cwnd:([0-9]+).*/\1/g')
  if [ ! -z "$CWND" ]; then
    printf "cwnd=$CWND, approx kb given 1500 MSS $(($CWND * 1500 / 1024))kb\n";
  fi
done

