obsd_arch    = "amd64"
obsd_version = "7.8"
img_variant  = "full"
disk_size_gb = "10"
box_version  = "0.1.0"

qemu_use_uefi = true
qemu_smp      = 2
hcp_upload    = false

vagrant_box = true

packer_dir_http           = "../packer_httproot"
packer_dir_vagrantkeys    = "../packer_vagrantkeys"
packer_dir_output_qemu    = "../output/qemu"
packer_dir_output_vagrant = "../output/box"