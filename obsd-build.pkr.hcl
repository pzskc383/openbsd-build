packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "install_img" {
  type    = string
  default = "install77.img"
}

variable "mirror_base" {
  type    = string
  default = "https://ftp2.eu.openbsd.org/pub/OpenBSD/7.7/amd64"
}


variable "root_password" {
  type      = string
  sensitive = true
  default   = "iloveyou"
}

# data "http" "install_img_checksum_file" {
#   url = "${var.mirror_base}/SHA256"
# }

# locals {
#   img_checksum = "sha256:${regex("${var.install_img}.* = ([0-9a-f]+)$", data.http.install_img_checksum.body)}"
# }

source "qemu" "virt_machine" {
  vm_name          = "obsd-build"

  accelerator    = "kvm"
  headless       = true
  disk_interface = "virtio"
  net_device     = "virtio-net"
  machine_type   = "q35"
  memory         = 8192

  disk_size        = "100G"
  disk_compression = true
  format           = "qcow2"

  boot_command = ["a<enter><wait15s>", "http://10.0.2.2:8557/install<enter><wait2s>", "i<enter><wait2s>", "<wait4m>", "exit<enter>"]
  boot_wait    = "30s"

  http_directory = "packer_httproot"
  http_port_max  = 8557
  http_port_min  = 8557

  iso_checksum    = "file:${var.mirror_base}/SHA256"
  iso_url         = "${var.mirror_base}/${var.install_img}"

  output_directory = "output"
  shutdown_command = "halt -p"

  ssh_password     = var.root_password
  ssh_port         = 22
  ssh_timeout      = "3000s"
  ssh_username     = "root"

  vnc_port_max     = 5979
  vnc_port_min     = 5979
}

build {
  sources = ["source.qemu.virt_machine"]
}
