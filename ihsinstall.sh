#!/bin/sh

# This script installs IIM, IHS, PLG, and WCT. 
#  If there's no global IIM, a new one is installed, bootstrapped by 1.6.0
#  If an older global IIM is found, it's updated to 1.8.5

# Dependencies: Nearly nothing

# IIM master password, used to encrypt/obfuscate individual credentials.
MASTERPASS="WebAS"

usage() {
  echo "$0 [-r /path/to/driverdownload|URL to repository] -U your-ibm.com.id -P your-ibm.com-password -i /path/to/installroot"
  exit 1
}

# Why the PID? This makes it relatively safe to remove the install dir without going through IIM.
INSTDIR=$HOME/inst.$$
PKGDL="http://www.ibm.com/software/repositorymanager/V9WASSupplements"

while getopts "i:r:u:p:" flag
do
  case $flag in
    i) INSTDIR=$OPTARG ;;
    r) PKGDL=$OPTARG ;;
    u) USER=$OPTARG ;;
    p) PASS=$OPTARG ;;
  esac
done

# Make sure credentials are provided if a URL is beign used
if echo $PKGDL | grep http > /dev/null; then
  USER_REQUIRED=1
  if [ -z "$USER" -o -z "$PASS" ]; then
     echo "-U/-P are required if -r is a URL or omitted";
     usage
  fi 
fi

# Find IIM
POSSIBLE_GLOBAL_IMS="/c/opt/Moonstone/IM /opt/IM /opt/IBM/InstallationManager /opt/Moonstone/InstallationManager /opt/Moonstone/IM"
for PIM in $POSSIBLE_GLOBAL_IMS; do
   if [ -x $PIM/eclipse/tools/imcl.exe ]; then
     IIMDL=$PIM
     IMCL=$PIM/eclipse/tools/imcl.exe
     IMUTILSC=$PIM/eclipse/tools/imutilsc.exe
     GLOBAL=1
   fi
   if [ -x $PIM/eclipse/tools/imcl ];  then
     IIMDL=$PIM
     IMCL=$PIM/eclipse/tools/imcl
     IMUTILSC=$PIM/eclipse/tools/imutilsc
     GLOBAL=1
   fi
done

# Make sure it's 1.8.5 or later, or update it
if [ $GLOBAL = 1 ]; then
   VER=`$IMCL -version | egrep ^Version:|awk '{print $2}'`
   MAJOR=`echo $VER | awk 'BEGIN { FS = "." } ; { print $1 }'`
   MINOR=`echo $VER | awk 'BEGIN { FS = "." } ; { print $2 }'`
   REV=`echo $VER | awk 'BEGIN { FS = "." } ; { print $3 }'`

   NEEDUPDATE=1
   if [ $MAJOR -ge 2 ]; then
      NEEDUPDATE=0
   elif [ $MINOR -ge 9 ]; then
      NEEDUPDATE=0
   elif [ $REV -ge 5 ]; then
      NEEDUPDATE=0
   fi

   if [ $NEEDUPDATE -eq 1 ]; then
    $IMCL install com.ibm.cic.agent -acceptLicense -showProgress -repositories ftp://public.dhe.ibm.com/software/rationalsdp/v7/im/185/repository/ -prompt
   fi
fi

# We need a global IIM. Grab the 1.6.0 full agent and use the raw kit to install 1.8.5
if [ -z "$GLOBAL" ]; then
    wget -q ftp://public.dhe.ibm.com/software/rationalsdp/v7/im/16/zips/agent.installer.linux.gtk.x86_64_1.6.0.20120831_1216.zip -O /tmp/iimold.zip
    mkdir /tmp/iimold
    (cd /tmp/iimold && unzip /tmp/iimold.zip)

    # Use the unpacked IIM zip to install 1.8.5 from the repo.
    /tmp/iimold/tools/imcl install com.ibm.cic.agent -acceptLicense  -repositories ftp://public.dhe.ibm.com/software/rationalsdp/v7/im/185/repository/ 
    IIMDL=/opt/IBM/InstallationManager
    IMCL=$IIMDL/eclipse/tools/imcl
    IMUTILSC=$IIMDL/eclipse/tools/imutilsc
fi

echo "$MASTERPASS" > $IIMDL/iim.password

# Save IBM ID creds
if [ -n "$USER_REQUIRED" ]; then
    $IMUTILSC saveCredential \
    -url $PKGDL \
    -secureStorageFile $IIMDL/iim.storage -masterPasswordFile  $IIMDL/iim.password   \
    -userName $USER -userPassword $PASS          
fi


#$IMCL listAvailablePackages \
#     -repositories $PKGDL  \
#     -secureStorageFile $IIMDL/iim.storage -masterPasswordFile  $IIMDL/iim.password 


# Use the installed kit to install IHS
$IMCL install com.ibm.websphere.IHS.v90 com.ibm.java.jdk.v8   \
     -repositories $PKGDL \
     -preferences "com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=true" \
     -secureStorageFile $IIMDL/iim.storage -masterPasswordFile  $IIMDL/iim.password \
     -acceptLicense -showProgress \
     -installationDirectory $INSTDIR/IHS

$IMCL install com.ibm.websphere.PLG.v90 com.ibm.java.jdk.v8  \
     -repositories $PKGDL \
     -preferences "com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=true" \
     -secureStorageFile $IIMDL/iim.storage -masterPasswordFile  $IIMDL/iim.password \
     -acceptLicense -showProgress \
     -installationDirectory $INSTDIR/HTTP_Plugins

$IMCL install com.ibm.websphere.WCT.v90 com.ibm.java.jdk.v8 \
     -repositories $PKGDL \
     -preferences "com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=true" \
     -secureStorageFile $IIMDL/iim.storage -masterPasswordFile  $IIMDL/iim.password \
     -acceptLicense -showProgress \
     -installationDirectory $INSTDIR/WCT


# TODO: Run a remote wctcmd.sh?
