#!/bin/sh

#lynx -listonly -dump https://www.openbsd.org/ftp.html |grep pub/OpenBSD|awk '{print $2}' > mirrors
#netselect -s10 -t30 $(sed 's@^.*//\([^/]*\)/.*$@\1@' mirrors| sort -u) |awk '{print $2}' > topten
#while read -r host; do echo "$(grep $host mirrors)"; echo ; done < topten
#rm mirrors topten 2>/dev/null

err() {
  [ -n "$1" ] && echo "$1" >&2
  exit 1
}

gen_root_password() {
  dd if=/dev/random bs=1 |tr -dc ',-:@-Z^-{'|head -c 14
}

select_file_mirror() {
  echo https://ftp2.eu.openbsd.org
}

select_cvs_mirror() {
  echo anoncvs.eu.openbsd.org
}

download_minirootfs() {
  [ -e miniroot.fs ] && return
  wget "$1/SHA256" || err "dowloading $fn from $1/$fn failed!"
  wget "$1/miniroot${2}.fs" || err "dowloading $fn from $1/$fn failed!"
  sha256sum -c --ignore-missing SHA256 || err "checksum failed"
  rm SHA256
  mv "miniroot${2}.fs" miniroot.fs
}



template_install() {
  eval "echo \"$(cat "./templates/install-${VERSION}.tpl.sh")\""
}

create_new_image() {
  [ -e "$1" ] && rm -f "$1">/dev/null
  qemu-img create -f qcow2 "$1" 10240M
}

chat_serial() {
  [ -p serial ] || mkfifo ./serial
  exec 3&<serial 
  done=0
  while [ $done -eq 0 ]; do
    read -r line <&3
    echo line: $line >&2
  done
}

MIRROR=${MIRROR:-$(select_file_mirror)}
ANONCVS=${ANONCVS:-$(select_cvs_mirror)}
FLAVOUR=${FLAVOUR:-current}

if [ "$FLAVOUR" = current ] ; then
  VERSION=6.2
  MIRROR_PATH="pub/OpenBSD/snapshots/amd64"
elif [ "$FLAVOUR" = release ]; then
  VERSION=6.1
  MIRROR_PATH="pub/OpenBSD/${VERSION}/amd64"
else
  err "wrong \$FLAVOUR: ${FLAVOUR}! supply either current or release"
fi
export MIRROR MIRROR_PATH ANONCVS FLAVOUR VERSION

create_new_image build.img
download_minirootfs "$MIRROR/$MIRROR_PATH" "$(echo "$VERSION"|tr -d '.')"
chat_serial &

qemu-system-x86_64 \
  -machine type=pc,accel=kvm \
  -m 512M \
  -boot once=d \
  -device virtio-serial-pci -chardev pipe,id=ch0,path=serial,mux=on  \
  -device virtserialport,chardev=ch0,name=serial0 \
  -drive file=build.img,if=virtio,cache=writeback,discard=ignore,format=qcow2 \
  -drive file=miniroot.fs,format=raw \
  -netdev user,id=user-net0 \
  -device virtio-net-pci,netdev=user-net0 \
  -nographic

