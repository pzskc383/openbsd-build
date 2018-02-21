#!/bin/sh

# settings
MIRROR_HOST=${MIRROR_HOST:-https://ftp2.eu.openbsd.org}
VERSION=${VERSION:-current}
INSTALL_SOURCE=${INSTALL_SOURCE:-minimal}

# defaults & checks
if [ -z "$ROOT_PASSWORD" ] ; then
  ROOT_PASSWORD=$(dd if=/dev/random bs=1 |tr -dc ',-:@-Z^-{'|head -c 14)
fi

if [ "$VERSION" = current ]; then
  ISO_TAG=62
  FTP_TAG=snapshots
else
  ISO_TAG="$(echo $VERSION|tr -d'.')"
  FTP_TAG=$VERSION
fi

if [ "$INSTALL_SOURCE" = full ] ; then
  ISO_NAME="install${ISO_TAG}.iso"
  SET_LOCATION=cd
  VERIFY_SETS=yes
else
  ISO_NAME="cd${ISO_TAG}.iso"
  SET_LOCATION=http
  VERIFY_SETS=no
fi

MIRROR_BASE="pub/OpenBSD/${FTP_TAG}/amd64"
SSH_PUBKEY="$(cat ./keys/obsd-build-access.pub)"

if [ -d ./output ]; then
  echo cleaning old output.
  rm -rf ./output
fi

echo generating answers file.
eval "echo \"$(cat ./packer_httproot/install.tpl.sh )\"" \
  >./packer_httproot/install 2>/dev/null


echo running packer.
PACKER_KEY_INTERVAL=10ms # bit faster
CHECKPOINT_DISABLE=1 # don't phone home
[ -t 1 ] || { PACKER_NO_COLOR=1; export PACKER_NO_COLOR; }
export MIRROR_HOST MIRROR_BASE ISO_NAME ROOT_PASSWORD
export PACKER_KEY_INTERVAL CHECKPOINT_DISABLE
packer build packer.json

if [ $? -eq 0 ]; then
  echo build successful.
  printf "root password: '%s'\n" "$ROOT_PASSWORD"
fi
