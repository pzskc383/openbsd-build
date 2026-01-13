#!/bin/sh
set -e -u
set -x

BASEPATH="${PACKER_HTTP_ADDR}/mirror/7.8"

ftp -o - "${BASEPATH}/ports.tar.gz" | doas -u vagrant tar - /usr xzf -
    