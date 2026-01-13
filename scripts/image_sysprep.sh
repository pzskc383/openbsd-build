#!/bin/sh
set -e -u

set -x

rm -rf \
     /etc/ssh/ssh_host* \
     /etc/random.seed \
     /var/db/host.random \
     /etc/isakmpd/private/local.key \
     /etc/isakmpd/local.pub \
     /etc/iked/private/local.key \
     /etc/isakmpd/local.pub \
     /etc/machine-id \
     /tmp/*

awk '/ffs/{print $2}' < /etc/fstab |while read -r mnt; do
    dd if=/dev/zero of="${mnt}/z" bs=1M || true
    rm -f "${mnt}/z"
done