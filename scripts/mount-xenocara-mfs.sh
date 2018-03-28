#!/bin/sh
set -eu

if mount|grep -qF 'on /usr/xenocara'; then
    umount /usr/xenocara
fi

echo Mounting /usr/xenocara as mfs
mount_mfs -P/dev/sd0g -s1G -onosuid,nodev,rw swap /usr/xenocara
