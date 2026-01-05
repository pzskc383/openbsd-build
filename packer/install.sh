#!/bin/sh
set -e -u

server=$1
shift

ftp -o - http://${server}/install.conf > /auto_install.conf
echo HTTP Server = ${server} >> /auto_install.conf
ftp -o - http://${server}/disklabel.txt > /disklabel.txt
ifconfig vio0 -autoconf

exec /autoinstall