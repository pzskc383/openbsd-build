#!/bin/sh
set -eu

mount |grep -qF 'on /usr/obj' >/dev/null && umount /usr/obj

newfs -g67000 -h16 -otime /dev/rsd0h

mount /usr/obj

for d in /usr/obj/{bsd,x11}; do
    mkdir -p $d
    chown build:wobj $d
    chmod 770 $d
done

for d in /usr/obj/ports{,.bulk,.update,.locks}; do
    mkdir -p $d
    chown _pbuild:wobj $d
    chmod 775 $d
done
