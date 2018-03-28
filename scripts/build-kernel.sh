#!/bin/sh
set -eu

cd /usr/src/sys/arch/amd64/compile/GENERIC.MP

make obj
make config
make -j4 && make install
make clean

echo /usr/local/sbin/start-on-rebuild.sh >> /etc/rc.local
reboot
