#!/bin/sh -e -u

set -x

usermod -G wsrc vagrant

mkdir -p /usr/xenocara /usr/ports
chgrp wsrc /usr/xenocara /usr/ports
chmod 775 /usr/xenocara /usr/ports

BASEPATH="${PACKER_HTTP_ADDR}/mirror/7.8"

if [ "${PACKER_SETUP_SOURCE-0}" -eq 1 ] || [ "${PACKER_SETUP_PORTS-0}" -eq 1 ]; then
    ftp -o - "${BASEPATH}/src.tar.gz" | doas -u vagrant tar -C /usr/src xzf -
    ftp -o - "${BASEPATH}/sys.tar.gz" | doas -u vagrant tar -C /usr/src xzf -

    ftp -o - "${BASEPATH}/xenocara.tar.gz" | doas -u vagrant tar -C /usr/xenocara xzf -
fi

if [ "${PACKER_SETUP_PORTS-0}" -eq 1 ]; then
    ftp -o - "${BASEPATH}/ports.tar.gz" | doas -u vagrant tar - /usr xzf -
fi
    