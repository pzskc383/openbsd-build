#!/bin/sh

MIRROR=${MIRROR:-https://ftp2.eu.openbsd.org}
ANONCVS=${ANONCVS:-anoncvs.eu.openbsd.org}
SOURCE=${SOURCE:-minimal}
FLAVOUR=${FLAVOUR:-release}

if [ "$FLAVOUR" = current ] ; then
  VERSION=6.2
  ISO_PATH=snapshots
else
  VERSION=6.1
  ISO_PATH=$VERSION
fi
VERSION_DOTLESS="${VERSION%.*}${VERSION#*.}"
ANSWERS="./packer_httproot/install-${VERSION}.tpl.sh"

[ -d ./iso ] || mkdir -p iso
[ -d ./output ] && rm -rf ./output 2>/dev/null

if ! [ -e "$ANSWERS" ]; then
  echo "hm! install template not found"
  echo "path: $ANSWERS"
  exit 1
fi

if [ "$SOURCE" = full ] ; then
  ISO_NAME=install${VERSION_DOTLESS}.iso
  SET_LOCATION=cd
  VERIFY_SETS=yes
else
  ISO_NAME=cd${VERSION_DOTLESS}.iso
  SET_LOCATION=http
  VERIFY_SETS=no
fi

echo preparing to build new OpenBSD vm.
echo install from: "$ISO_NAME"
echo flavour: "$FLAVOUR" '(' "$VERSION" ')'
echo mirror: "$MIRROR"
echo csv host: "$ANONCVS"

if [ -z "$ROOT_PASSWORD" ] ; then
  ROOT_PASSWORD=$(dd if=/dev/random bs=1 |tr -dc ',-:@-Z^-{'|head -c 14)
  printf "root password: %s\n\n" "$ROOT_PASSWORD"
fi

echo sleeping for 5 seconds before actual build
echo press ^C if you don\'t like it
#sleep 2

eval "echo \"$(cat ./packer_httproot/install-${VERSION}.tpl.sh )\"" \
  >./packer_httproot/install 2>/dev/null

export MIRROR ISO_NAME ISO_PATH ANONCVS ANSWERS ROOT_PASSWORD



PACKER_KEY_INTERVAL=10ms # bit faster
CHECKPOINT_DISABLE=1 # don't phone home
[ -t 1 ] || { PACKER_NO_COLOR=1; export PACKER_NO_COLOR; }
export PACKER_KEY_INTERVAL CHECKPOINT_DISABLE
export PACKER_LOG=1

exec packer build packer.json

# qemu-system-x86_64 \
#  -machine type=pc,accel=kvm \
#  -m 512M \
#  -name obsd-build \
#  -boot once=n \
#  -drive file=output/obsd-build.img,if=virtio,cache=writeback,discard=ignore,format=qcow2 \
#  -netdev user,id=user.0,hostfwd=tcp::2901-:22 \
#  -device virtio-net,netdev=user.0 \
#  -vnc 127.0.0.1:79 \
#  -display sdl
