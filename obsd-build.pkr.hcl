packer {
  required_plugins {
    vagrant = {
      version = "~> 1"
      source  = "github.com/hashicorp/vagrant"
    }
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "obsd_arch" {
  type        = string
  default     = "amd64"
  description = "Architecture (amd64|arm64)"
}

variable "obsd_version" {
  type        = string
  default     = "7.8"
  description = "OpenBSD release version"
}

variable "obsd_set_list" {
  type        = string
  description = "Set of sets to install, base|no-x|full|ports|src|cloud"
  default     = "full"
}


variable "disk_size_gb" {
  type    = number
  default = 10
}

variable "box_version" {
  type    = string
  default = "0.1.0"
}

locals {
  http_datadir    = "${path.root}/packer_httproot"
  install_datadir = "${path.root}/packer_httproot/mirror/${var.obsd_arch}"
  disklabelfile   = "${path.root}/packer/disklabel.${var.obsd_set_list}.txt"
  box_name        = "openbsd-${var.obsd_arch}-${var.obsd_set_list}"

  obsd_short_version = replace(var.obsd_version, ".", "")
  obsd_cd_image      = "cd${local.obsd_short_version}.iso"

  qemu_binary  = var.obsd_arch == "amd64" ? "qemu-system-x86_64" : "qemu-system-aarch64"
  qemu_machine = var.obsd_arch == "amd64" ? "q35" : "virt"
  qemu_accel   = var.obsd_arch == "amd64" ? "kvm" : "none"

  arm64_efi_code = "/usr/share/edk2/aarch64/QEMU_EFI.fd"
  arm64_efi_vars = "/usr/share/edk2/aarch64/QEMU_VARS.fd"
  amd64_efi_code = "/usr/share/OVMF/OVMF_CODE.fd"
  amd64_efi_vars = "/usr/share/OVMF/OVMF_VARS.fd"

  qemu_efi_code   = var.obsd_arch == "amd64" ? local.amd64_efi_code : local.arm64_efi_code
  qemu_efi_vars   = var.obsd_arch == "amd64" ? local.amd64_efi_vars : local.arm64_efi_vars
  qemu_use_pflash = var.obsd_arch == "amd64" ? true : false



  checksum_parts = [for l in split("\n", file("${local.install_datadir}/SHA256")) : split(" ", l)[3] if strcontains(l, local.obsd_cd_image)]
  iso_checksum   = local.checksum_parts[0]

  register_box_cmd = <<-EOF
  #!/bin/sh
  set -x
  echo registering box ${local.box_name}
  vagrant box add -a ${var.obsd_arch}  \
    --provider libvirt  \
    --name ${local.box_name}  \
    ./output/${local.box_name}.box
  EOF

  set_list_map = {
    base   = "-* bsd bsd.rd bsd.mp base* site*"
    "no-x" = "-* bsd bsd.rd bsd.mp base* site* man* comp* game*"
    full   = "-* bsd bsd.rd bsd.mp base* site* man* comp* game* xbase* xfont* xshare* xserv*"
  }
  headless     = (var.obsd_set_list == "base" || var.obsd_set_list == "no-x")
  run_x        = local.headless ? "yes" : "no"
  default_com0 = "no" # local.headless ? "no" : "yes"
}

source "file" "autoinstall" {
  content = templatefile("${path.root}/packer/install.conf.tmpl", {
    ssh_public_key   = chomp(file("${path.root}/packer/vagrant-keys/vagrant.pub.rsa"))
    server_directory = "mirror/${var.obsd_arch}"
    set_names        = local.set_list_map[var.obsd_set_list]
    run_x            = local.run_x
    default_com0     = local.default_com0
  })
  target = "${local.http_datadir}/install.conf"
}

source "file" "disklabel" {
  content = file(local.disklabelfile)
  target  = "${local.http_datadir}/disklabel.txt"
}


source "qemu" "virt_machine" {
  vm_name = local.box_name

  qemu_binary  = local.qemu_binary
  machine_type = local.qemu_machine
  accelerator  = local.qemu_accel

  efi_boot         = true
  efi_drop_efivars = true

  efi_firmware_code = local.qemu_efi_code
  efi_firmware_vars = local.qemu_efi_vars
  use_pflash        = false

  disk_interface = "virtio"
  cpus           = 2
  memory         = "1024"

  disk_size        = "${var.disk_size_gb}G"
  disk_compression = true
  format           = "qcow2"

  communicator = "ssh"
  ssh_username = "root"

  ssh_private_key_file = "${path.root}/packer/vagrant-keys/vagrant.key.rsa"

  boot_command = [
    "s<enter><wait2s>",
    "ifconfig vio0 autoconf<enter><wait10s>",
    "ftp -o i http://{{ .HTTPIP }}:{{ .HTTPPort }}/i<enter><wait3s>",
    "sh -x i {{ .HTTPIP }}:{{ .HTTPPort }}<enter>",
    "<wait4m>",
  ]

  boot_key_interval = "50ms"
  boot_wait         = "20s"

  http_directory = local.http_datadir

  headless = true

  vnc_port_max = 5923
  vnc_port_min = 5923

  iso_url      = "file://${abspath(local.install_datadir)}/${local.obsd_cd_image}"
  iso_checksum = "sha256:${local.iso_checksum}"

  output_directory = "output"
  shutdown_command = "shutdown -p now"

}

build {
  name = "openbsd-boot-files"
  sources = [
    "source.file.disklabel",
    "source.file.autoinstall"
  ]
}

build {
  name = "openbsd-box"
  sources = [
    "source.qemu.virt_machine",
  ]
  post-processors {
    // post-processor "artifice" {
    //   files = ["./output/${local.box_name}"]
    // }
    post-processor "vagrant" {
      architecture         = var.obsd_arch
      keep_input_artifact  = true
      provider_override    = "libvirt"
      vagrantfile_template = "${path.root}/packer/Vagrantfile.base.rb"
      output               = "./output/${local.box_name}.box"
    }
    post-processor "shell-local" {
      inline = [local.register_box_cmd]
    }
    // post-processor "artifice" {
    //   files = ["./output/${local.box_name}.box"]
    // }
    # post-processor "vagrant-cloud" {
    #   access_token = "${var.cloud_token}"
    #   box_tag      = "pzskc383/mybox"
    #   version      = var.box_version
    #   architecture = var.obsd_arch
    # }
  }


}