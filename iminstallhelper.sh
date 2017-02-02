#!/bin/bash

# covener's script to list/install/patch whatever is found 
# in an IM repository with an global or unzipped IIM.

ACTION="help"

usage() { 
  echo "$0 list|install|uninstall|update|install-im|install-local-im  [-l] -r some-repo [-i install-root]  -p offering|\"list\""
  printf "\nList available packages to install:"
  printf "\n\t$0 list -r /path/to/driverdownload|URL to repository"
  printf "\n\nInstall package:"
  printf "\n\t$0 install -r /path/to/driverdownload|URL -p com.ibm.... -i /opt/InstallRoot"
  printf "\n\nInstall fixpack (same as full install):"
  printf "\n\t$0 install -r /path/to/driverdownload|URL -p com.ibm.... -i /opt/InstallRoot"
  printf "\n\nApply IFIX:"
  printf "\n\t$0 update -r /path/to/ifix.zip -i /opt/InstallRoot"
  printf "\n\nRemove last IFIX:"
  printf "\n\t$0 uninstall -i /opt/InstallRoot"
  printf "\n\nInstall global IIM:"
  printf "\n\t$0 install-im"
  printf "\n\nOptions:\n" 
  printf "\t -r specifies a repo -- zip or http/https\n"
  printf "\t -U/P are user/pass for online repos. You should be prompted w/o these\n"
  printf "\t -t forces a temporary IIM in the -i dir\n"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi
ACTION=$1;
shift

# Look for a global IIM install by default.
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

NEED_AUTH=0
while getopts "lti:r:p:U:P:x:" flag
do
  case $flag in
    i) INSTDIR=$OPTARG ;;
    r) PKGDL=$OPTARG ;;
    p) PKGS=$OPTARG ;;
    U) REPOUSER=$OPTARG ; NEED_AUTH=1 ;;
    P) PASS=$OPTARG ;;
    l) GLOBAL=0;;
  esac
done

if [ $ACTION = "install" -o $ACTION = "update" -o $ACTION = "uninstall" ]; then
    if [ -z "$INSTDIR" ]; then
      echo "$0: -i install-path is required for install, update, or uninstall"
      exit 1
    fi
fi

# Find the global IM unless -l was forced
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

# Override these for the local IM scenario
IMDATA=""
IMSHARED=""
if [ $GLOBAL -eq 0 ]; then
  IMDATA="$IIMDL/IM-data"
  IMSHARED=$"IIMDL/IM-shared"
fi

# Setup parameters for real command-line IM invocations
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

IMDATA_ARG=""
IMSHARED_ARG=""

if [ $GLOBAL -eq 0 ]; then
  IMDATA_ARG="-dataLocation $IMDATA_NATIVE"
  # XXX: Not used?
  IMSHARED_ARG="-sharedDataLocation $IMDATA_NATIVE"
fi

# IM functions

listAvailablePackages() { 
  echo "  Determing available packages in $PKGDL..."
  # One time w/o backticks to potentially prompt  
  set -x
  $IMCL listAvailablePackages -repositories $PKGDL $IMDATA_ARG -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE -prompt 
  set +x
  PKGS=`$IMCL listAvailablePackages -repositories $PKGDL $IMDATA_ARG -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE -prompt`
}

lisInstalledPackages() { 
  echo "  Determing installed packages in $INSTDIR..."
  set -x
  PACKAGE=`$IMCL listInstalledPackages  -installationDirectory $INSTDIR $IMDATA_ARG | grep com.ibm`
  set +x
}

listAvailableFixes() { 
  FIXES=""
  echo "  Determing available fixes in $PKGDL..."
  set -x
  for PKG in $PACKAGE; do
   FIX=`$IMCL listAvailableFixes $PKG -repositories $PKGDL \
        $IMDATA_ARG \
        -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE`
   FIXES="$FIXES $FIX"
  done
  set +x
}

installFix() { 
  echo "  Installing $PKGS from $PKGDL into $INSTDIR ..."
  if [ -d /cygdrive ]; then
    $INSTDIR/bin/versionInfo.bat -ifixes
  else
    if [ -f "$INSTDIR/bin/versionInfo.sh" ]; then
      $INSTDIR/bin/versionInfo.sh -ifixes
    fi
  fi
  set -x
  $IMCL install $PKGS -repositories $PKGDL                   \
        $IMDATA_ARG \
        -installationDirectory "$INSTDIR"                    \
        -acceptLicense \
        -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE

  set +x
  if [ -d /cygdrive ]; then
    $INSTDIR/bin/versionInfo.bat -ifixes
  else
    if [ -f "$INSTDIR/bin/versionInfo.sh" ]; then
      $INSTDIR/bin/versionInfo.sh -ifixes
    fi
  fi

}

checkRepoAuth() { 
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
    echo "No $STORAGE if your repo is GSA, stash a PW in ~/iim.password and run e.g. \n\n" 
    echo "\t $IMUTILSC  saveCredential -url $PKGDL -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE -userName youruser -userPassword yourpass" 
    exit 1
  fi
  
  if [ $NEED_AUTH -eq 1 -a ! -w "$STORAGE_NATIVE" ]; then
    echo "Warning, $STORAGE_NATIVE is not writable. Passwords provided interactively will not be saved"
  fi
  
  if [ $NEED_AUTH -eq 1 -a -n "$REPOUSER" ]; then
   $IMUTILSC saveCredential -url $PKGDL -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE -userName $REPOUSER 
  fi
}


if [ $ACTION = "list" ] ; then
  listAvailablePackages
  exit 0
fi

if [ $ACTION = "install-im" ]; then
    echo "Trying to install global IIM"
    if [ -d "/opt/IBM/InstallationManager" ]; then
      echo "/opt/IBM/InstallationManager exists"
      exit 1
    fi
    # We need a global IIM. Grab the 1.6.0 full agent and use the raw kit to install 1.8.5
    OS=`uname -s`
    rm -f /tmp/iimold.zip
    if [ ! -f /tmp/iimold.zip ]; then
      echo "Downloading old IIM to boostrap..."
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
    /tmp/iimold/tools/imcl install com.ibm.cic.agent -acceptLicense  -repositories ftp://public.dhe.ibm.com/software/rationalsdp/v7/im/185/repository/

    IIMDL=/opt/IBM/InstallationManager
    IMCL=$IIMDL/eclipse/tools/imcl
    IMUTILSC=$IIMDL/eclipse/tools/imutilsc
    exit  0
fi
if [ $ACTION = "install-local-im" ]; then
  echo "install-local-im not yet implemented"
  exit 1
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


# checkRepoAuth

ARCH=`uname -m`
OPKGS=$PKGS

if [ $ACTION = "uninstall" ]; then
    set -x
    INSTDIR=$UNINSTALL
    lisInstalledPackages
    $IMCL $IMDATA_ARG uninstall $PACKAGE -installationDirectory $UNINSTALL 
    set +x
    exit 0
fi

if [ $ACTION = "update" ];  then
  # Return value in PACKAGES
  lisInstalledPackages 
  # Return value in FIXES 
  listAvailableFixes
  
  if [ x"${OPKGS}" = x"list" ]; then
    echo "Found Fixes: "
    echo "  $FIXES"
    echo "Hint: $0 update $@ -p $FIXES"
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
if [ $ACTION = "install" ]; then
    if echo $PKGS | grep v9 ; then
      # first package to install
      SUB=`echo $PKGS|awk '{print $1}'`
      if echo $PKGS | grep EDGE >/dev/null; then
              $IMCL install $PKGS -repositories $PKGDL  \
              $IMDATA_ARG \
                -acceptLicense -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE                                   \
                -showProgress                                     
      else 
        $IMCL install $PKGS                                  \
            -repositories $PKGDL                             \
            -installationDirectory   "$INSTDIR"           \
            -acceptLicense -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE    \
                $IMDATA_ARG \
            -showProgress                                     
      fi
    else
        # 8.0/8.5
        for PKG in $PKGS; do
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
              -installationDirectory   "$INSTDIR"            \
              -properties "$PROPS"                              \
              -acceptLicense -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE                                   \
              -showProgress                                     
          else
            $IMCL install $PKG -repositories $PKGDL                                                   \
              $IMDATA_ARG \
              -installationDirectory   "$INSTDIR"                                                  \
              -acceptLicense -secureStorageFile $STORAGE_NATIVE  -masterPasswordFile $MASTER_NATIVE   \
              -showProgress                                     
          fi
        done
    fi
fi

