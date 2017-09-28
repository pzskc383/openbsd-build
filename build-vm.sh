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

setup_serv() {
  [ -d ./serve ] || mkdir ./serve

  for fn in pxeboot bsd.rd SHA256 ; do
    [ -e "./serve/$fn" ] && continue
    wget "$1/$fn" -O "./serve/$fn" || err "dowloading $fn from $1/$fn failed!"
  done

  [ -L "./serve/auto_install" ] || ln -s pxeboot ./serve/auto_install

  ( { cd ./serve && sha256sum -c --ignore-missing SHA256; } || \
    err "checksum failed" )

  ( rm -rf ./serve/etc >/dev/null && mkdir ./serve/etc ) || \
    err "can't clean /etc serv dir"

  dd if=/dev/urandom bs=256 count=1 of=./serve/etc/random.seed >/dev/null 2>&1
  echo boot tftp:bsd.rd > ./serve/etc/boot.conf

  eval "echo \"$(cat "./templates/install-${VERSION}.tpl.sh")\"" \
    > ./serve/install.conf
}

create_new_image() {
  [ -e "$1" ] && rm -f "$1">/dev/null
  qemu-img create -f qcow2 "$1" 10240M
}

run_http_serv() {
  fifo=$(pwd)/http
  [ -p "${fifo}.in" ] || mkfifo "${fifo}.in"
  [ -p "${fifo}.out" ] || mkfifo "${fifo}.out"

  set -x

  ( LF=$(printf "%b_" '\r'); LF=${LF%_}

  exec 3<"${fifo}.out" 4>"${fifo}.in"

  while : ; do
    read request <&3
    file="${request#GET*/}"
    file="${file% HTTP/*}"
    file="${file%\?*}"

    bd-log requested file "${file}"

    while : ; do
      read header
      header=${header%$LF}
      [ "$header" = "" ] && break;
    done

    if [ -r "./serve/$file" ] ; then
      printf "%s\r\n%s\r\n\r\n" "HTTP/1.0 200 OK" "Content-type: text/plain" >&4
      cat "./serve/$file" >&4
      printf "\r\n" >&4
      bd-log served file "${file}"
    else
      printf "%s\r\n\r\n" "HTTP/1.0 404 NOT FOUND" >&4
      bd-log file "${file}" not found
    fi

  done ) &
  serv_pid=$!
  trap 'kill $serv_pid' EXIT
}

if [ $# -eq 1 ] && [ "$1" = -http ]; then
  bd-log hi
  exit
fi


MIRROR=${MIRROR:-$(select_file_mirror)}
ANONCVS=${ANONCVS:-$(select_cvs_mirror)}
FLAVOUR=${FLAVOUR:-release}

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

setup_serv "$MIRROR/$MIRROR_PATH"
#create_new_image obsd-build.img
run_http_serv &


  #-object filter-dump,id=usernetdump,netdev=usernet,file=./usernet.pcap \
#strace -o qemu.strace -f \
qemu-system-x86_64 \
  -machine type=pc,accel=kvm \
  -m 512M \
  -boot once=n \
  -drive file=obsd-build.img,if=virtio,cache=writeback,discard=ignore,format=qcow2 \
  -chardev pipe,id=pipedev,path=./http \
  -netdev 'user,id=user-net0,tftp=./serve/,bootfile=auto_install,guestfwd=:10.0.2.2:80-chardev:pipedev' \
  -device virtio-net-pci,netdev=user-net0 \
  -display sdl \
  -name obsd-build
