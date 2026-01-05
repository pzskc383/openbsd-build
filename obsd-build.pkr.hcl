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
  description = "Architecture"
}

variable "obsd_set_list" {
  type        = string
  description = "Set of sets to install, base|no-x|full|ports|src|cloud"
  default     = "full"
}

variable "obsd_cd_image" {
  type        = string
  description = "name of cd image"
  default     = "cd78.iso"
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

  checksum_parts = [for l in split("\n", file("${local.install_datadir}/SHA256")) : split(" ", l)[3] if strcontains(l, var.obsd_cd_image)]
  iso_checksum   = local.checksum_parts[0]

  register_box_cmd = <<-EOF
  #!/bin/sh
  echo registering box ${local.box_name}
  vagrant box add -a ${var.obsd_arch}  \\
    --provider libvirt  \\
    --box-version ${var.box_version}  \\
    --name ${local.box_name}  \\
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

  accelerator    = "kvm"
  efi_boot       = true
  disk_interface = "virtio"
  cpus           = 2
  machine_type   = "q35"
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
  vga      = "virtio"

  vnc_port_max = 5923
  vnc_port_min = 5923

  iso_url      = "file://${abspath(local.install_datadir)}/${var.obsd_cd_image}"
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
    post-processor "artifice" {
      files = ["./output/${local.box_name}"]
    }
    post-processor "vagrant" {
      architecture         = var.obsd_arch
      keep_input_artifact  = true
      provider_override    = "libvirt"
      vagrantfile_template = "${path.root}/packer/Vagrantfile.base.rb"
      output               = "./output/${local.box_name}.box"
    }
    // post-processor "shell-local" {
    //   inline = [local.register_box_cmd]
    // }
    post-processor "artifice" {
      files = ["./output/${local.box_name}.box"]
    }
    # post-processor "vagrant-cloud" {
    #   access_token = "${var.cloud_token}"
    #   box_tag      = "pzskc383/mybox"
    #   version      = var.box_version
    #   architecture = var.obsd_arch
    # }
  }


}