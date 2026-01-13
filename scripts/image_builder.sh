#!/bin/sh
set -e -u
set -x

usermod -G wsrc vagrant

mkdir -p /usr/xenocara /usr/ports || true
chgrp wsrc /usr/xenocara /usr/ports
chmod 775 /usr/xenocara /usr/ports