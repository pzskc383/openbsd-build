#!/bin/sh
set -e -u

BASEPATH="${PACKER_HTTP_ADDR}/mirror/7.8"

ftp -o - "${BASEPATH}/ports.tar.gz" | doas -u vagrant tar - /usr xzf -
    