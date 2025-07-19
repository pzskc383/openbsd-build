packer {
  required_plugins {
    libvirt = {
      version = ">= 0.5.0"
      source  = "github.com/thomasklein94/libvirt"
    }
  }
}

variable "install_img" {
  type    = string
  default = "${env("INSTALL_IMG")}"
}

variable "mirror_base" {
  type    = string
  default = "${env("MIRROR_BASE")}"
}

variable "mirror_host" {
  type    = string
  default = "${env("MIRROR_HOST")}"
}

variable "root_password" {
  type    = string
  default = "${env("ROOT_PASSWORD")}"
}

data "http" "install_img_checksum_file" {
  url = "${var.mirror_host}/${var.mirror_base}/SHA256"
}

locals  {
  img_checksum = regex("${install_img}.* = ([0-9a-f]+)$", data.http.install_img_checksum.body)
}

source "libvirt" "virt_machine" {
  libvirt_uri = "qemu:///system"
  domain_name = "obsd-build"

  memory = 16
  vcpu   = 4

  shutdown_mode          = "acpi"
  domain_type            = "kvm"
  chipset                = "q35"
  arch                   = "x86_64"
  network_address_source = "lease"
  artifact_volume_alias   = "disk"

  communicator {
    communicator         = "ssh"
    ssh_username         = "root"
    ssh_private_key_file = "./keys/obsd-build-access"
  }

  volume {
    alias = "install"
    pool = "iso"
    name = var.install_img
    source {
      type     = "external"
      urls     = ["${var.mirror_host}/${var.mirror_base}/${var.install_img}"]
      checksum = local.img_checksum
    }
    format = "raw"
    bus    = "virtio"
  }

  volume {
    alias    = "disk"
    pool     = "default"
    name     = "obsd-build.qcow2"
    format   = "qcow2"
    bus      = "virtio"
    capacity = "100G"
  }

  network_interface {
    type    = "managed"
    network = "default"
    alias   = "communicator"
    model   = "virtio"
  }
}



build {
  sources = ["source.libvirt.virt_machine"]
  provisioner "shell" {
    inline = ["echo HI"]
  }
}
