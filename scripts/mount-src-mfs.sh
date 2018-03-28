#!/bin/sh
set -eu

if mount|grep -qF 'on /usr/src'; then
    umount /usr/src
fi

echo Mounting /usr/src as mfs
mount_mfs -P/dev/sd0f -s1G -onosuid,nodev,rw swap /usr/src
