#!/bin/sh
set -e -u

CLOUD_INIT_VERSION=25.3

pkg_add python%3

(
    cd /tmp

    echo "Downloading cloud-init ${CLOUD_INIT_VERSION}"
    ftp -O - "https://github.com/canonical/cloud-init/archive/refs/tags/${CLOUD_INIT_VERSION}.tar.gz" | \
        tar xzf -

    cd "cloud-init-${CLOUD_INIT_VERSION}"

    sed -i 's!_ROOT_TMPDIR = "/run/cloud-init/tmp"!_ROOT_TMPDIR = "/var/run/cloud-init/tmp"!' cloudinit/temp_utils.py
    sed -i 's!^    usr_lib_exec = "/usr/lib"!    usr_lib_exec = "/usr/local/lib"!' cloudinit/distros/__init__.py

    if ! pkg_info dmidecode > /dev/null 2>&1 ; then
        sed -i '/dmidecode/d' tools/build-on-openbsd
    fi

    ./tools/build-on-openbsd
)

rm -r "/tmp/cloud-init-${CLOUD_INIT_VERSION}"