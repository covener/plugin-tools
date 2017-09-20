#!/bin/sh
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ $# -lt 1 ]; then
  echo "$0 /IHS/root foo.kdb"
  exit 1
fi

KDB=$2

$1/bin/gskcapicmd -cert -list -stashed -db $KDB | grep -v 'secret key'|grep \* | awk '{print $2}'|sed -e s'/"//g'  |\
while read line; do 
   echo $line
   $1/bin/gskcapicmd -cert -details -stashed -label "$line" -db $KDB | grep "Not After" | sed -e 's/^/    /g'
done

# TODO: parse it
