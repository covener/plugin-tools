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

# Change me if needed
IMCL=/opt/IM/eclipse/tools/imcl
IMCL=/opt/IBM/InstallationManager/eclipse/tools/imcl

if [ ! -x $IMCL ]; then
  IIMDL=${IIMDL:-$HOME/iim}
  IMCL=$IIMDL/tools/imcl
  INST=$HOME/inst
fi


echo "Don't use this script if you also use iminstallhelper!. Use iminstallhelper to install ifixes".

OP="$1"
INSTDIR="$2"
FIXARG="$3"

if [ -z "$INSTDIR" ] ; then
  echo
  echo "$0 list|remove|install /path/to/product [fix-name|fix-path]"
  echo
  echo -e "\t Install hint: $0 install /opt/IBM/HTTPServer /tmp/8.5.5.4-WS-WASIHS-IFPI9999.pak"
  echo -e "\t Remove hint: $0 list /opt/IBM/HTTPServer && $0 remove /opt/IBM/HTTPServer 8.5.5.4-WS-WASIHS-LinuxX3264-IFPI99999_8.5.5004.20151014_1655"
  exit 1
fi

if [ ! -d "$INSTDIR" ] ; then
  echo "$INSTDIR is supposed to be an installation directory, but doesn't exist"
  exit 1
fi

case $OP in
  list)
          ;;
  install)
          if [ -z "$FIXARG" ]; then
             echo "$0 install -i $INSTDIR -f /path/to/fix.zip"
             exit 1
          fi
          if [ ! -f "$FIXARG" ]; then
             echo "-f fixarg does not exist";
             exit 1
          fi
          ;;
  uninstall|remove)
          OP=remove
          if [ -z "$FIXARG" ]; then
             echo "$0 remove -i $INSTDIR -f /path/to/fix.zip"
             exit 1
          fi
          ;;
  *)
     echo "$0 list|remove|install /path/to/product [fix-name|fix-path]"
     exit 1
     ;;
esac

PACKAGE=`$IMCL listInstalledPackages  -installationDirectory $INSTDIR | egrep ^com.ibm|grep -v jdk`
FIXES=`$IMCL listInstalledPackages  -installationDirectory $INSTDIR | grep WS- | tr '\n' ","`

case $OP in
  list)
    echo "Package: $PACKAGE"
    echo "Interim Fixes: " : $FIXES
    echo "Available fixes:"
    $IMCL listAvailableFixes $PACKAGE  -repositories $FIXARG |  egrep ^[89]
    ;;
  install)
    FIX=`$IMCL listAvailableFixes $PACKAGE  -repositories $FIXARG |  egrep ^[89]`
    $IMCL install $FIX -repositories $FIXARG -installationDirectory "$INSTDIR" 
    ;;
  remove)
    $IMCL uninstall $FIXARG -installationDirectory "$INSTDIR" 
    ;;
esac





