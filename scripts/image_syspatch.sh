#!/bin/sh -e -u

pkill reorder_kernel
sed -e 's/.checkfs/#checkfs/g' /usr/sbin/syspatch > /root/syspatch
ksh /root/syspatch
rm /root/syspatch
ksh /usr/sbin/syspatch