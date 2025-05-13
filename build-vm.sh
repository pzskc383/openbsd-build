#!/bin/sh

# settings
MIRROR_HOST=${MIRROR_HOST:-https://ftp2.eu.openbsd.org}
VERSION=${VERSION:-7.7}
BRANCH=${BRANCH:-current}
INSTALL_SOURCE=${INSTALL_SOURCE:-minimal}
PUBKEY_PATH=./keys/obsd-build-access.pub
RUN_TEST=0

usage() {
  echo "Usage: $0 [-m mirror ] [-k path to ssh pubkey ] [-i install source ]"
  echo "[-v openbsd version ] [-b openbsd branch ] [-t test image ]"
  exit 2
}

while getopts "m:k:v:b:i:t" opt "$@"; do
  case "$opt" in
    m)
      MIRROR_HOST="${OPTARG}"
      ;;
    k)
      PUBKEY_PATH="${OPTARG}"
      if ! [ -r "$PUBKEY_PATH" ]; then
        echo $PUBKEY_PATH not found!
        usage
      fi
      ;;
    v)
      VERSION="${OPTARG}"
      case $VERSION in *.*) ;; *)
        echo wrong version $VERSION
        usage; ;;
      esac
      ;;
    b)
      BRANCH="${OPTARG}"
      case $BRANCH in release|current) ;; *)
        echo wrong branc, must be release or current
        usage; ;;
      esac
      ;;
    i)
      INSTALL_SOURCE="${OPTARG}"
      case $INSTALL_SOURCE in full|minimal) ;; *)
        echo wrong install source, must be full or minimal
        usage; ;;
      esac
      ;;
    t)
      RUN_TEST=1
      ;;
    ?)
      ;;
  esac
done

SHORTVERSION="$(echo $VERSION|tr -d ".")"
# defaults & checks
if [ "$BRANCH" = current ]; then
  FTP_TAG=snapshots
else
  FTP_TAG=$VERSION
fi

if [ "$INSTALL_SOURCE" = full ] ; then
  INSTALL_IMG_NAME="install${SHORTVERSION}.img"
  SET_LOCATION=cd
  VERIFY_SETS=yes
else
  INSTALL_IMG_NAME="cd${SHORTVERSION}.img"
  SET_LOCATION=http
  VERIFY_SETS=no
fi

MIRROR_BASE="pub/OpenBSD/${FTP_TAG}/amd64"

ROOT_PASSWORD=$(tr -dc ',-:@-Z^-{' </dev/urandom |head -c 14)

if ! [ -r "$PUBKEY_PATH" ]; then
  echo generating ssh pubkey
  ssh-keygen -q -f "$(echo $PUBKEY_PATH|sed s/.pub//)"
fi
SSH_PUBKEY="$(cat $PUBKEY_PATH)"

echo generating answers file.
eval "echo \"$(cat ./packer_httproot/install.tpl.sh )\"" \
  >./packer_httproot/install 2>/dev/null

if [ -d ./output ]; then
  echo cleaning old output.
  rm -rf ./output
fi

if ! [ -d ./iso ]; then
  echo creating iso directory.
  mkdir -p ./iso
fi



echo running packer.

export PACKER_KEY_INTERVAL=10ms # bit faster
export CHECKPOINT_DISABLE=1 # don't phone home
[ -t 1 ] || { PACKER_NO_COLOR=1; export PACKER_NO_COLOR; }
set -x

#export PACKER_LOG=1
#export PACKER_LIBVIRT_STREAM_CONSOLE=1

export PK_VAR_mirror_base="${MIRROR_HOST}/${MIRROR_BASE}"
export PK_VAR_install_img="${INSTALL_IMG_NAME}"
export PK_VAR_root_password="${ROOT_PASSWORD}"

templatefile=obsd-build.pkr.hcl

packer validate $templatefile && \
packer build $templatefile

if [ $? -eq 0 ]; then
  echo build successful.
  printf "root password: '%s'\n" "$ROOT_PASSWORD"
fi
