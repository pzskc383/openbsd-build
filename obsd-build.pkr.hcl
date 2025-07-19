packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "vnc_port" {
  type    = number
  default = 5923
}

variable "install_img" {
  type    = string
  default = "install77.iso"
}

variable "mirror_base" {
  type    = string
  default = "https://ftp2.eu.openbsd.org/pub/OpenBSD/7.7/amd64"
}


variable "root_password" {
  type      = string
  sensitive = true
}

# data "http" "install_img_checksum_file" {
#   url = "${var.mirror_base}/SHA256"
# }

# locals {
#   img_checksum = "sha256:${regex("${var.install_img}.* = ([0-9a-f]+)$", data.http.install_img_checksum.body)}"
# }

locals {
  http_datadir  = "${path.root}/packer_httproot"
  installfile   = "install.conf"
  disklabelfile = "disklabel"
}

source "qemu" "virt_machine" {
  vm_name = "obsd-build"

  accelerator    = "kvm"
  disk_interface = "virtio"
  machine_type   = "q35"
  memory         = 8192

  disk_size        = "100G"
  disk_compression = true
  format           = "qcow2"

  communicator         = "ssh"
  ssh_username         = "root"
  ssh_private_key_file = "${path.root}/keys/obsd-build"
  # qemuargs = [
  #   [ "-netdev", "user,hostfwd=tcp::{{ .SSHHostPort }}-:22,id=forward"],
  #   [ "-device", "virtio-net,netdev=forward,id=net0"]
  # ]


  boot_command = [
    "s<enter><wait5s>",
    "ifconfig vio0 autoconf<enter><wait3s>",
    "ftp -Vo - http://{{ .HTTPIP }}:{{ .HTTPPort }}/${local.installfile} > /auto_install.conf<enter><wait3s>",
    "ftp -Vo - http://{{ .HTTPIP }}:{{ .HTTPPort }}/${local.disklabelfile} > /install_disklabel<enter><wait3s>",
    "ifconfig vio0 -autoconf<enter><wait3s>",
    "/autoinstall<enter><wait3s>",
    "<wait4m>",
    "root<enter><wait3s>",
    "${var.root_password}<enter><wait2s>"
  ]
  boot_key_interval = "50ms"
  boot_wait         = "15s"

  http_directory = local.http_datadir
  # http_port_max  = 8557
  # http_port_min  = 8557

  headless     = true
  vnc_port_max = var.vnc_port
  vnc_port_min = var.vnc_port

  iso_checksum = "file:${var.mirror_base}/SHA256"
  iso_url      = "${var.mirror_base}/${var.install_img}"

  output_directory = "output"
  shutdown_command = "shutdown -p now"

}

build {
  sources = ["source.qemu.virt_machine"]
}
