#!/bin/sh

rm -rf /var/ports/{log,lock}/* >/dev/null

dpb \
    -D AWAYS_CLEAN=1 \
    -D CONTROL=/tmp/dpb.sock \
    -D LOGDIR=/var/ports/log \
    -D LOCKDIR=/var/ports/lock \
    -D RECORD= \
    -j 3 \
    /var/portlist
