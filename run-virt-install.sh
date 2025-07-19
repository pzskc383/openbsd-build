#!/bin/sh

NAME=boot
UUID=$(uuidgen)
MACPART='00:00:a6'

virt-install \
    --connect qemu://system \
    --name ${NAME} \
    --metadata uuid=${UUID} \
    --memory 2048 \
    --machine q35 \
    --disk /var/lib/libvirt/images/obsd-root-boot.img,format=raw,bus=virtio \
    --cdrom /var/lib/libvirt/isos/install63.iso --boot cdrom \
    --pm suspend_to_mem=on \
    --network network=obsd,model=virtio,mac=52:54:00:${MACPART} \
    --watchdog i6300esb,action=pause --panic default \
    --sound none
