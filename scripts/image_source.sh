#!/bin/sh
set -e -u
set -x

BASEPATH="${PACKER_HTTP_ADDR}/mirror/7.8"

ftp -o - "${BASEPATH}/src.tar.gz" | doas -u vagrant tar -C /usr/src xzf -
ftp -o - "${BASEPATH}/sys.tar.gz" | doas -u vagrant tar -C /usr/src xzf -

ftp -o - "${BASEPATH}/xenocara.tar.gz" | doas -u vagrant tar -C /usr/xenocara xzf -