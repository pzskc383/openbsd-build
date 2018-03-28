#!/bin/sh
set -eu

cvs() {
    env CVSROOT=anoncvs@anoncvs.eu.openbsd.org:/cvs \
        HOME=/var/srcfetch \
        doas -u srcfetch 
}

git() {
    env HOME=/var/srcfetch \
        doas -u srcfetch 
}

echo "updating /usr/src"
cd /usr/src
cvs -q up -Pd

echo "updating /usr/xenocara"
cd /usr/xenocara
cvs -q up -Pd

echo "updating main ports tree"
cd /usr/ports
cvs -q up -Pd

echo "updating openbsd-wip"
cd /usr/local/ports/gh-wip
git pull --rebase

echo "updating my custom ports"
cd /usr/local/ports/my 
git pull --rebase

