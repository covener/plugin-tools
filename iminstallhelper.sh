#!/usr/bin/env bash

# covener's script to list/install/patch whatever is found 
# in an IM repository with an global or unzipped IIM.

# Prerequisites to using this script.  
#  1) unpack IIM for this platform in ~/iim
#  3) If you use e-images, you must unzip diskX for an offering and pass the unzipped dir as the argument

usage() { 
  echo "$0 [-g] -r /path/to/driverdownload|URL to repository  [ -i /path/to/installroot|-u /path/to/install-to-update ] -p offering-or-fix-to-install|\"list\""
  printf "\n\nThis script helps you install and update an IM-based WAS product using online repositories or zips (repos or interim fixes). it can use a global or unzipped IIM\n"
  printf "\tInstall\n"
  printf "\t\t List packages: $0 -r your-repo -p list -i ~/ihs8557\n"
  printf "\t\t Install: $0 -r your-repo -p com.ibm.websphere.IHS.v85_8.5.5007.20150820_2140  -i ~/ihs8557\n"
  printf "\t\t\t V9 hint: Must select a JDK for install like: -p \"com.ibm.websphere.IHSILAN.v90 com.ibm.java.jdk.v8\"\n\n"
  printf "\tUpdate to fixpack\n"
  printf "\t\tList Contents: $0 -r your-repo -p list -u ~/ihs8557\n"
  printf "\t\tInstall Contents: $0 -r your-repo -p com.ibm.websphere.IHS.v85_8.5.5007.20150820_2140 -u ~/ihs8557\n\n"
  printf "\tAdd IFIX\n"
  printf "\t\tList contents:  $0 -r ~/8.5.5.7-WS-WASIHS-OS390-IFPI70372.zip -u ~/ihs8557\n"
  printf "\t\tInstall contents: $0 -r ~/8.5.5.7-WS-WASIHS-OS390-IFPI70372.zip -u  ~/ihs8557 -p 8.5.5.7-WS-WASIHS-OS390-IFPI70372_8.5.5007.20161010_1459\n"
  printf "\tUninstall: $0 -x /installroot \n"

  printf "\nOptions:\n" 
  printf "\t -r specifies a repo -- zip or http/https\n"
  printf "\t -U/P are user/pass for online repos. You should be prompted w/o these\n"
  printf "\t -t forces a temporary IIM in the -i dir\n"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

# Change to zero to avoid global IIM instal.

GLOBAL=1
# No configuration below!

IIMDL=${IIMDL:-$HOME/iim}
IMCL=$IIMDL/tools/imcl
IMUTILSC=$IIMDL/tools/imutilsc
OS=`uname`

if [ -x /opt/csw/bin/wget ]; then
  PATH=$PATH:/opt/csw/bin
fi
PKGS=list
INSTDIR=$IIMDL

NEED_AUTH=0
while getopts "gti:r:p:u:U:P:x:" flag
do
  case $flag in
    i) INSTDIR=$OPTARG ;;
    u) UPDATEINST=$OPTARG 
       INSTDIR=$UPDATEINST;;
    r) PKGDL=$OPTARG ;;
    p) PKGS=$OPTARG ;;
    U) REPOUSER=$OPTARG ; NEED_AUTH=1 ;;
    P) PASS=$OPTARG ;;
    g) GLOBAL=1;;
    t) TEMPIM=1;;
    x) UNINSTALL=$OPTARG;;
 
  esac
done

if [ ! "$PKGS" = "list" -a -z "$INSTDIR" ]; then
  if [ -z $UNINSTALL ]; then
    echo "One of -i or -u is required"
    exit 1
  fi
fi

if [ x"$GLOBAL" = "x1" ]; then
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
fi

STORAGE=$HOME/iim.storage
MASTER=$HOME/iim.password

IMDATA=""
IMSHARED=""
if [ $GLOBAL -eq 0 ]; then
  IMDATA="$IIMDL/IM-data"
  IMSHARED=$IIMDL/IM-shared
fi

if [ ! -d "$IIMDL" ]; then
    # Borrowed from ihsinstall.sh
    echo "no $IIMDL or global IM detected. Installing 185 via 160..."
    # We need a global IIM. Grab the 1.6.0 full agent and use the raw kit to install 1.8.5
    OS=`uname -s`
    if [ ! -f /tmp/iimold.zip ]; then
      case $OS in
        AIX) wget -q ftp://public.dhe.ibm.com/software/rationalsdp/v7/im/16/zips/agent.installer.aix.motif.ppc_1.6.0.20120831_1216.zip -O /tmp/iimold.zip
             ;;
        Linux) wget -q ftp://public.dhe.ibm.com/software/rationalsdp/v7/im/16/zips/agent.installer.linux.gtk.x86_64_1.6.0.20120831_1216.zip -O /tmp/iimold.zip
             ;;
      esac
    fi 
    mkdir /tmp/iimold
    (cd /tmp/iimold && unzip /tmp/iimold.zip)

    # Use the unpacked IIM zip to install 1.8.5 from the repo.
    if [ -z "$TEMPIM" ]; then
      /tmp/iimold/tools/imcl install com.ibm.cic.agent -acceptLicense  -repositories ftp://public.dhe.ibm.com/software/rationalsdp/v7/im/185/repository/
    else
      if [ -f /etc/.ibm/registry/InstallationManager.dat ]; then
          echo "You seem to have a global IIM but asked for a scratch/temp IIM.  This doesn't work.  Hide/restore /etc/.ibm/registry/InstallationManager.dat?"
          exit 1
      fi
      /tmp/iimold/tools/imcl install com.ibm.cic.agent -acceptLicense  -repositories ftp://public.dhe.ibm.com/software/rationalsdp/v7/im/185/repository/ \
            -installationDirectory $INSTDIR -dataLocation $IMDATA
    fi
    IIMDL=/opt/IBM/InstallationManager
    IMCL=$IIMDL/eclipse/tools/imcl
    IMUTILSC=$IIMDL/eclipse/tools/imutilsc
    GLOBAL=1
fi

IMCL_LOCAL=$IIMDL/imcl.local
if [ $GLOBAL = "1" ]; then
  # No need for a local
  IMCL_LOCAL=$IMCL
fi

if [ -d /cygdrive ]; then
  INSTPREFIX=c:/inst
else
  INSTPREFIX=$HOME/inst
fi

if [ -z "$PKGS" ]; then
  echo "Assuming -p list"
  PKGS=list
fi


if [ -d /cygdrive ]; then
  if [ $GLOBAL -eq 0 ]; then
    IMDATA_NATIVE=`cygpath -m $IMDATA`
    IMSHARED_NATIVE=`cygpath -m $IMSHARED`
  else
    IMDATA_NATIVE=""
    IMSHARED_NATIVE=""
  fi
  STORAGE_NATIVE=`cygpath -m $STORAGE`
  MASTER_NATIVE=`cygpath -m $MASTER`
else
  STORAGE_NATIVE=$STORAGE
  MASTER_NATIVE=$MASTER
  IMDATA_NATIVE=$IMDATA
  IMSHARED_NATIVE=$IMSHARED
fi

if [ ! -w "$STORAGE_NATIVE" ]; then
  echo "Warning, $STORAGE_NATIVE is not writable. Passwords provided interactively will not be saved"
fi

IMDATA_ARG=""
IMSHARED_ARG=""

if [ $GLOBAL -eq 0 ]; then
  IMDATA_ARG="-dataLocation $IMDATA_NATIVE"
  # XXX: Not used?
  IMSHARED_ARG="-sharedDataLocation $IMDATA_NATIVE"
fi

if [ ! -d "$PKGDL" -a ! -f "$PKGDL" ]; then
  OUT=`wget --no-check-certificate "$PKGDL" 2>&1`
  # modern wget 
  if [ $? -eq 6 ]; then
    NEED_AUTH=1
  fi
  # ancient wget 
  if echo "$OUT" | grep "401" >/dev/null; then
    NEED_AUTH=1
  fi
else
  # IIM wont take a relative path.
  FC=`echo $PKGDL|sed -e 's/^\(.\).*/\1/'`
  if [ ! $FC = "/" ]; then
    PKGDL=$PWD/$PKGDL
  fi
fi


if [ $NEED_AUTH -eq 1 -a ! -f "$STORAGE" ]; then
  echo "No $STORAGE if your repo is GSA, stash a PW in ~/iim.password and run e.g. \n\n\t $IMUTILSC  saveCredential -url $PKGDL -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE -userName youruser -userPassword yourpass" 
  exit 1
fi

if [ $NEED_AUTH -eq 1 -a -n "$REPOUSER" ]; then
 $IMUTILSC saveCredential -url $PKGDL -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE -userName $REPOUSER 
fi

listAvailablePackages() { 
  echo "  Determing available packages in $PKGDL..."
  # One time w/o backticks to potentially prompt  
  $IMCL listAvailablePackages -repositories $PKGDL $IMDATA_ARG -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE -prompt 
  PKGS=`$IMCL listAvailablePackages -repositories $PKGDL $IMDATA_ARG -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE -prompt`
}

lisInstalledPackages() { 
  echo "  Determing installed packages in $UPDATEINST..."
  PACKAGE=`$IMCL listInstalledPackages  -installationDirectory $UPDATEINST $IMDATA_ARG | grep com.ibm`
}

listAvailableFixes() { 
  FIXES=""
  echo "  Determing available fixes in $PKGDL..."
  for PKG in $PACKAGE; do
   FIX=`$IMCL listAvailableFixes $PKG -repositories $PKGDL \
        $IMDATA_ARG \
        -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE`
   FIXES="$FIXES $FIX"
  done
}

installFix() { 
  echo "  Installing $PKGS from $PKGDL into $UPDATEINST..."
  if [ -d /cygdrive ]; then
    $UPDATEINST/bin/versionInfo.bat -ifixes
  else
    $UPDATEINST/bin/versionInfo.sh -ifixes
  fi

  $IMCL install $PKGS -repositories $PKGDL                   \
        $IMDATA_ARG \
        -installationDirectory "$UPDATEINST"                    \
        -acceptLicense \
        -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE

  if [ -d /cygdrive ]; then
    $UPDATEINST/bin/versionInfo.bat -ifixes
  else
    $UPDATEINST/bin/versionInfo.sh -ifixes
  fi

}


ARCH=`uname -m`
OPKGS=$PKGS

if [ -n "$UNINSTALL" ]; then
    set -x
    UPDATEINST=$UNINSTALL
    lisInstalledPackages
    $IMCL $IMDATA_ARG uninstall $PACKAGE -installationDirectory $UNINSTALL 
    set +x
    exit 
fi


if [ -n "$UPDATEINST" ];  then
  # Return value in PACKAGES
  lisInstalledPackages 
  # Return value in FIXES 
  listAvailableFixes
  
  if [ x"${OPKGS}" = x"list" ]; then
    echo "Found Fixes: "
    echo "  $FIXES"
    echo "Hint: $0 $@ -p $FIXES"
    exit 0
  fi
  if [ x"${OPKGS}" = x"all" ]; then
    echo "Installing fix with: $0 $@ -p $FIXES"
    $0 $@ -p $FIXES
    exit 0
  fi
 
  installFix
  exit 0

fi

if echo "$PKGS"|xargs | grep credentials 2>&1 >/dev/null; then
  echo "No Credentials for $PKGDL"
  echo "$IIMDL/tools/imutilsc  saveCredential -url $PKGDL -userName youruser -userPassword yourpass -secureStorageFile ~/iim.storage  -masterPasswordFile ~/iim.password"
  exit 1
fi


if [ x"${OPKGS}" = x"list" ]; then
   listAvailablePackages
   for PKG in $PKGS; do
     printf --  "$PKG\n"
   done
   exit 1
fi

if echo $PKGS | grep v9 ; then
  if [ -n "$UPDATEINST" ]; then
      ACTUALINST=$UPDATEINST
  elif [ -n "$INSTDIR" ]; then
      ACTUALINST=$INSTDIR
  else
    # first package to install
    SUB=`echo $PKGS|awk '{print $1}'`
    ACTUALINST="$HOME/inst/$SUB"
  fi
if echo $PKGS | grep EDGE >/dev/null; then
        $IMCL install $PKGS -repositories $PKGDL  \
          $IMDATA_ARG \
          -acceptLicense -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE                                   \
          -showProgress                                     
else 
  $IMCL install $PKGS                                  \
      -repositories $PKGDL                             \
      -installationDirectory   "$ACTUALINST"           \
      -acceptLicense -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE    \
          $IMDATA_ARG \
      -showProgress                                     
fi

else
    # 8.0/8.5
    for PKG in $PKGS; do
      if [ -n "$INSTDIR" ]; then
        ACTUALINST=$INSTDIR
      elif [ -n "$UPDATEINST" ]; then
          ACTUALINST=$UPDATEINST
      else
      # first package to install
        SUB=`echo $PKGS|awk '{print $1}'`
        ACTUALINST="$INSTDIR/$SUB"
      fi
  
      PROPS=""
      case $PKG in 
        *APPCLIENT*) PROPS="user.wasjava=java8,user.appclient.serverHostname=localhost,user.appclient.serverPort=2809";;
        *IHS*) PROPS="user.wasjava=java6,user.ihs.httpPort=80,user.ihs.allowNonRootSilentInstall=true";;
        *WAS*) PROPS="user.wasjava=java8;;"
      esac
      if echo $PKG | grep EDGE >/dev/null; then
        $IMCL install $PKG -repositories $PKGDL  \
          $IMDATA_ARG \
          -acceptLicense -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE                                   \
          -showProgress                                     
      elif [ -n "$PROPS" ]; then
        $IMCL install $PKG -repositories $PKGDL  \
          $IMDATA_ARG \
          -installationDirectory   "$ACTUALINST"            \
          -properties "$PROPS"                              \
          -acceptLicense -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE                                   \
          -showProgress                                     
      else
        $IMCL install $PKG -repositories $PKGDL                                                   \
          $IMDATA_ARG \
          -installationDirectory   "$ACTUALINST"                                                  \
          -acceptLicense -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE   \
          -showProgress                                     
      fi
    done
fi

