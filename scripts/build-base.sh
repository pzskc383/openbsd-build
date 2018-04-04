#!/bin/sh
set -eu

sed -i -e '/start-on-rebuild.sh/d' /etc/rc.local || :

# ~/scripts/clean-obj.sh
# mount-src-mfs.sh

logger "starting build"
cd /usr/src
make obj && make build
logger "build done"

sysmerge
( cd /dev; sh MAKEDEV all )

mount /dest
export DESTDIR=/dest/base
export RELEASEDIR=/var/release
( cd /usr/src/etc; make release )
( cd /usr/src/distrib/sets; sh checkflist )
unset RELEASEDIR DESTDIR
