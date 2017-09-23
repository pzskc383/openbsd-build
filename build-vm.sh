#!/bin/sh

OPENBSD_MIRROR=${OPENBSD_MIRROR:-https://mirror.yandex.ru}
OPENBSD_ANONCVS=${OPENBSD_ANONCVS:-ftp.hostserver.de}
INSTALL_SOURCE=${INSTALL_SOURCE:-minimal}

if [ -z "$ROOT_PASSWORD" ] ; then
  ROOT_PASSWORD=$(dd if=/dev/random bs=1 |tr -dc ',-:@-Z^-{'|head -c 14)
  printf "root password: %s\n\n" "$ROOT_PASSWORD"
fi

if [ "$INSTALL_SOURCE" = full ] ; then
  OPENBSD_ISO_NAME=install62.iso
  SET_LOCATION=cd
  VERIFY_SETS=yes
else
  OPENBSD_ISO_NAME=cd62.iso
  SET_LOCATION=http
  VERIFY_SETS=no
fi

[ -d ./output-qemu ] && rm -rf ./output-qemu 2>/dev/null

eval "echo \"$(cat ./packer_httproot/install.tpl.sh )\"" \
  >./packer_httproot/install 2>/dev/null


PACKER_KEY_INTERVAL=10ms # bit faster
CHECKPOINT_DISABLE=1 # don't phone home
[ -t 1 ] || { PACKER_NO_COLOR=1; export PACKER_NO_COLOR; }

export OPENBSD_MIRROR OPENBSD_ISO_NAME ROOT_PASSWORD 
export PACKER_KEY_INTERVAL CHECKPOINT_DISABLE
exec packer build packer.json
