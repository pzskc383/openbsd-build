#!/bin/sh
set -eu

mount-xenocara-mfs.sh

logger "starting xenocara build"
cd /usr/xenocara
make bootstrap
make obj 
make build
logger "build done"

mount /dest
export DESTDIR=/dest/xbase
export RELEASEDIR=/var/release
make release
make checkdist
unset RELEASEDIR DESTDIR
