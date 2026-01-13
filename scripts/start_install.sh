#!/bin/sh
set -e -u

server=$1
variant=$2

ftp -o - "http://${server}/variants/${variant}/install.conf" > /auto_install.conf
echo "HTTP Server = ${server}" >> /auto_install.conf
ftp -o - "http://${server}/variants/${variant}/disklabel.txt" > /disklabel.txt
ifconfig vio0 -autoconf

exec /autoinstall