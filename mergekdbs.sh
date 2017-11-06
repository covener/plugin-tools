#!/bin/sh -x
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

# Put $IHSROOT/bin in your path!
# covener@gmail.com


set -e

if [ $# -lt 3 ]; then
  echo "$0 merged.kdb old1.kdb old2.kdb [old3.kdb...]"
  exit 1
fi

NEWKDB=$1
shift

if [ ! -f $NEWKDB ]; then
   gskcapicmd -keydb -create -db $NEWKDB -pw WebAS -stash
fi

DIR=`mktemp -d`

for OLDKDB in "$@"; do
gskcapicmd -cert -list -stashed -db $OLDKDB| grep ^\!| cut -d\! -f 2|sed -e s'/"//g'  \
| while read line; do 
   rm -f "$DIR/$line"
   gskcapicmd -cert -extract -stashed -target "$DIR/$line" -label "$line" -db $OLDKDB
done
done

find $DIR -type f | 
while read CA; do
   gskcapicmd -cert -add -db $NEWKDB -stashed -file "$CA" -label "`basename "$CA"`"
done



