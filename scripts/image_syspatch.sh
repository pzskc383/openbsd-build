#!/bin/sh
set -e -u

pkill -9 -xf '/bin/ksh .*reorder_kernel' || true
sleep 1
sed -e 's/.checkfs/#checkfs/g' /usr/sbin/syspatch > /root/syspatch
ksh /root/syspatch || true
rm /root/syspatch
ksh /usr/sbin/syspatch