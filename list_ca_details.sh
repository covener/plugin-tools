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

# Put gsk8capicmd in your path, and gsk8 libs in your shared library path.
# Redirect the output to a file and search / post-process.

# ecovener@us.ibm.com

if [ $# -lt 1 ]; then
  echo "$0 foo.kdb password"
  exit 1
fi

KDB=$1
PW=$2

if [ $# -eq 1 ]; then
 STHFILE=`echo $KDB | sed -e 's/kdb$/sth/g'`
 PW=`unstash.pl $STHFILE`
fi

gsk8capicmd -cert -list -db $KDB -pw "$PW" | grep ^\!| cut -d\! -f 2|sed -e s'/"//g'  \
| while read line; do 
   gsk8capicmd -cert -details -label "$line" -db $KDB -pw "$PW"; 
done



