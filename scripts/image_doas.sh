#!/bin/sh
set -e -u

cat <<EOF > /etc/doas.conf
permit nopass setenv { \
    FTPMODE PKG_CACHE PKG_PATH SM_PATH SSH_AUTH_SOCK \
    DESTDIR DISTDIR FETCH_CMD FLAVOR GROUP MAKE MAKECONF \
    MULTI_PACKAGES NOMAN OKAY_FILES OWNER PKG_DBDIR \
    PKG_DESTDIR PKG_TMPDIR PORTSDIR RELEASEDIR SHARED_ONLY \
    SUBPACKAGE WRKOBJDIR SUDO_PORT_V1 } :wsrc

permit keepenv :wheel
EOF

chmod 600 /etc/doas.conf

doas -C /etc/doas.conf