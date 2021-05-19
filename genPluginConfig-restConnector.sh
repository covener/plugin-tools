#!/usr/bin/env bash
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


# This script demonstrates how to call the Plugin Configuration Generator MBEAN
# on a lberty instance with the restConnector configured.
# Author: ecovener@us.ibm.com

# TODO: .netrc, remove bashisms

# Liberty setup hints: https://developer.ibm.com/wasdev/docs/accessing-libertys-jmx-rest-apis/

# <server>
#  <featureManager>
#    <feature>restConnector-1.0</feature>
#  </featureManager>
#  <quickStartSecurity userName="theUser" userPassword="thePassword"/>
#  <keyStore id="defaultKeyStore" password="Liberty"/>
#</server>


# Edit this section as desired
###########################################################################
# WebServer details
DEFAULT_PLUGIN_ROOT=/opt/IBM/HTTPServer_Plugins
DEFAULT_WEBSERVER_NAME=webserver1

# When configuring the restConnector, you have to specify at least a 
# quick-start security user and password. These will be visible in the
# process table.

JMX_USER=theUser
JMX_PASS=thePassword

WGET="wget -q --no-check-certificate"
###########################################################################

trap 'rm -f $TEMPFILE' EXIT

PLUGIN_ROOT=${2:-$DEFAULT_PLUGIN_ROOT}
WEBSERVER_NAME=${3:-$DEFAULT_WEBSERVER_NAME}

# Edit below at your own risk.

if [ $# -lt 1 ]; then
  echo "$0 https-URL [ plugin-root [ webserver-name ] ]"
  echo ""
  echo -e "Examples:"
  echo -e "\t $0 https://localhost:9443"
  echo -e "\t $0 https://localhost:9443 /opt/Plugins webserver1"
  exit 1
fi

URL=$1
# Remove trailing slash
URL=$(echo $URL | sed -e 's/\/$//')
# Remove https prefi
URL=$(echo $URL | sed -e 's/^https:\/\///')
# Remove the https:// prefix to allow host:port input to work too 
URL="https://${URL}"

$WGET --http-user=$JMX_USER --http-password=$JMX_PASS ${URL}/IBMJMXConnectorREST/mbeans/ -O/dev/null
RC=$?
if [ $RC -eq 6 ]; then
  echo "JMX Rest Connector credentials appear wrong, edit $0"
  exit $RC 
elif [ $RC -eq 4 ]; then
  echo "Network error with url $URL, check host/IP and port manually"
  exit $RC 
elif [ $RC -ne 0 ]; then
  echo "Unknown error $RC testing $URL/IBMJMXConnectorREST/mbeans/ returned an error (make sure restConnector feature is loaded on target server)."
  exit $RC
fi

# Prepare the payload for the POST
TEMPFILE=`mktemp`
cat <<==end > $TEMPFILE
{ 
   "params": [ 
             { "value": "$PLUGIN_ROOT"       , "type": "java.lang.String"},  
             { "value": "$WEBSERVER_NAME"    , "type": "java.lang.String"} 
           ], 
   "signature": ["java.lang.String", "java.lang.String"]
}
==end

BEAN_URL="${URL}/IBMJMXConnectorREST/mbeans/WebSphere%3Aname%3Dcom.ibm.ws.jmx.mbeans.generatePluginConfig/operations/generatePluginConfig"
$WGET --body-file $TEMPFILE --header="Content-Type: application/json" --method=POST  \
     --no-check-certificate --http-user=$JMX_USER --http-password=$JMX_PASS          \
     ${BEAN_URL}                                                                     \
     -O/dev/null
RC=$?

if [ $RC -eq 0 ]; then
  echo "Success, plugin-cfg.xml should have been generated on the Liberty server"
else
  echo "Unknown error $RC invoking $BEAN_URL (make sure restConnector feature is loaded on target server)."
  exit $RC
fi

