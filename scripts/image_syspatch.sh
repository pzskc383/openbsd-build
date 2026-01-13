#!/bin/sh
set -e -u
set -x

pkill -xf '/bin/ksh .*reorder_kernel' || true
sed -e 's/.checkfs/#checkfs/g' /usr/sbin/syspatch > /root/syspatch
ksh /root/syspatch || true
rm /root/syspatch
ksh /usr/sbin/syspatch