#!/bin/bash

PACKAGES="gtk2 libXft libXmu libXt libXtst compat-libstdc++-33 expat libXp libgcc libstdc++"

YUM=yum

if [ -x `which ibm-yum.sh`]; then
  YUM=ibm-yum.sh
elif [ -x /root/ibm-yum.sh ]; then
  YUM=/root/ibm-yum.sh
fi


ARCH=`uname -m`
ARCH2=$(uname -m | sed -e 's/ppc64/ppc/g' -e 's/s390x/s390/g' -e 's/x86_64/i686/g') 

if [ $ARCH != $ARCH2 ]; then
  for PKG in $PACKAGES; do
    PACKAGES="$PACKAGES $PKG.$ARCH2"
  done
fi

$YUM install $PACKAGES ksh

