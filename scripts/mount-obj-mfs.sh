#!/bin/sh
set -eu

if mount|grep -qF 'on /usr/obj'; then
    umount /usr/obj
fi

echo Mounting /usr/obj as mfs
mount_mfs -P/dev/sd0h -s4G -onosuid,nodev,rw swap /usr/obj
