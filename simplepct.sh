#!/bin/sh

# This script is an alternative to PCT for basic IHS + Liberty.
# Changes to this file will not be preserved.

WEBSERVER_NAME=webserver1

# Get absolute install root the hokey portable way 
CUR_DIR=`pwd`
BIN_DIR=`dirname ${0}`
cd ${BIN_DIR}/..
SR=`pwd`
cd $CUR_DIR

if [ -x /bin/readlink -a -x /bin/dash -a -z "$BASH_VERSION" ]; then
  if readlink /bin/sh | grep dash > /dev/null; then
    exec bash $0 "$@"
  fi
fi

if [ $# -ne 1 ]; then
  echo "$0 /path/to/PluginInstallRoot"
  exit 1
fi

if [ ! -f "$SR/conf/httpd.conf" ]; then
  echo "$0: No $SR/conf/httpd.conf, $0 must be run from the servers bin/ directory"
  exit 1
fi


# Validate the first parm, the Plugin install root
PLG_ROOT="$1"
if [ ! -d "$PLG_ROOT" ]; then
  echo "$0: $1 does not exist"
  exit 1
fi

PLG_BIN="$PLG_ROOT/bin/64bits"
OS=`uname -s`
if [ "$OS" = "OS/390" ]; then
  PLG_BIN="$PLG_ROOT/bin"
fi

if [ ! -f "$PLG_BIN/mod_was_ap24_http.so" ] ; then
  echo "$0: $1 does not look like a Plug-in installation root"
  exit 1
fi

# Remove trailing slash
PLG_ROOT=`echo $PLG_ROOT | sed -e 's@/$@@'`

if [ ! -w "$PLG_ROOT/config" ]; then
  echo "$0: $PLG_ROOT/config is not writable by the current user";
  exit 1
fi
if [ ! -w "$SR/conf/httpd.conf" ]; then
  echo "$0: $SR/conf/httpd.conf is not writable by the current user";
  exit 1
fi


if grep "LoadModule was_ap24_module" $SR/conf/httpd.conf >/dev/null; then
  echo "It appears some Plug-in configuration has already occurred"
  exit 1
fi

mkdir -p $PLG_ROOT/logs/$WEBSERVER_NAME
mkdir -p $PLG_ROOT/config/$WEBSERVER_NAME

echo "<IfFile \"$PLG_ROOT/config/$WEBSERVER_NAME/plugin-cfg.xml\">"                       >> "$SR/conf/httpd.conf"
echo "  LoadModule was_ap24_module \"$PLG_BIN/mod_was_ap24_http.so\""        >> "$SR/conf/httpd.conf"
echo "  WebSpherePluginConfig $\"PLG_ROOT/config/$WEBSERVER_NAME/plugin-cfg.xml\""        >> "$SR/conf/httpd.conf"
echo "</IfFile>"                                                                      >> "$SR/conf/httpd.conf"

cp $PLG_ROOT/etc/plugin-key.* $PLG_ROOT/config/$WEBSERVER_NAME/

echo "To continue, configure your server.xml with <pluginConfiguration pluginInstallRoot=\"$PLG_ROOT\" />, "
echo "then transfer your usr/servers/server-name/logs/state/plugin-cfg.xml to "
echo "'$PLG_ROOT/config/$WEBSERVER_NAME/plugin-cfg.xml'"

exit 0


