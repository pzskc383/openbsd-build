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
    sshkey = {
      version = ">= 1.1.0"
      source  = "github.com/ivoronin/sshkey"
    }
    password = {
      version = ">= 0.1.0"
      source  = "github.com/alexp-computematrix/password"
    }
    external = {
      version = "> 0.0.2"
      source  = "github.com/joomcode/external"
    }
  }
}

variable "obsd_arch" {
  type        = string
  default     = "amd64"
  description = "Architecture (amd64|arm64)"

  validation {
    condition     = var.obsd_arch == "amd64" || var.obsd_arch == "arm64"
    error_message = "obsd_version should be formatted as X.Y"
  }
}

variable "obsd_version" {
  type        = string
  default     = "7.8"
  description = "OpenBSD release version"
  validation {
    condition     = can(regex("[0-9]+.[0-9]+", var.obsd_version))
    error_message = "obsd_version should be formatted as X.Y"
  }
}

variable "obsd_img_variant" {
  type        = string
  description = "Image variant to build: base|no-x|full|ports|src|cloud"
  default     = "full"
}


variable "disk_size_gb" {
  type        = number
  description = "Root size in GB"
  default     = 10
}

variable "box_version" {
  type        = string
  description = "Semantic version of this box"
  default     = "0.1.0"
}

variable "qemu_use_uefi" {
  type        = bool
  description = "Whether to use UEFI for booting (implies GPT disk partitioning)"
  default     = true
}


data "sshkey" "packer" {
  name = "packer"
  type = "ed25519"
}

data "password" "root" {
  hash = "sha512"
}

data "password" "vagrant" {
  hash = "sha512"
}

locals {
  short_version = replace(var.obsd_version, ".", "")

  dir_httproot      = "${path.root}/packer_httproot"
  dir_vagrant_keys  = "${path.root}/vagrant-keys"
  dir_installmirror = "${path.root}/packer_httproot/mirror/${var.obsd_version}/${var.obsd_arch}"

  sets_variant_map = {
    base   = "-* bsd bsd.rd bsd.mp base*"
    "no-x" = "-* bsd bsd.rd bsd.mp base* man* comp* game*"
    full   = "-* bsd bsd.rd bsd.mp base* man* comp* game* xbase* xfont* xshare* xserv*"
    ports  = "-* bsd bsd.rd bsd.mp base* man* comp* game* xbase* xfont* xshare* xserv*"
    src    = "-* bsd bsd.rd bsd.mp base* man* comp* game* xbase* xfont* xshare* xserv*"
    cloud  = "-* bsd bsd.rd bsd.mp base* man* comp* game* xbase* xfont* xshare* xserv*"
  }

  set_names = local.sets_variant_map[var.obsd_img_variant]

  box_additional_tag_variant_map = {
    base   = "-base"
    "no-x" = "-no-x"
    full   = ""
    ports  = "-ports"
    src    = "-source"
    cloud  = "-cloud"
  }

  box_additional_tag = local.box_additional_tag_variant_map[var.obsd_img_variant]
  box_name           = "openbsd${local.short_version}-${var.obsd_arch}${local.box_additional_tag}"

  packer_bucket_name = local.box_name
  vagrant_box_tag    = "pzskc383/${local.box_name}"

  disklabel_variant_map = {
    base   = "base"
    "no-x" = "base"
    full   = "base"
    ports  = "ports"
    src    = "src"
    cloud  = "cloud"
  }

  disklabel_variant = local.disklabel_variant_map[var.obsd_img_variant]
  disklabel_file    = "${path.root}/templates/disklabel.${local.disklabel_variant}.txt"

  iso_filename = "cd${local.short_version}.iso"

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

  headless     = (var.obsd_img_variant == "base" || var.obsd_img_variant == "no-x")
  run_x        = local.headless ? "yes" : "no"
  default_com0 = "no" # local.headless ? "no" : "yes"

  iso_checksum_parts = [
    for l in split("\n", file("${local.dir_installmirror}/SHA256")) :
    split(" ", l)[3] if strcontains(l, local.iso_filename)
  ]
  iso_checksum = local.iso_checksum_parts[0]

  register_box_cmd = <<-EOF
  #!/bin/sh
  echo registering box ${local.box_name}
  vagrant box add -f \
    -a ${var.obsd_arch} \
    --provider libvirt \
    --name ${local.box_name} \
    ./output/vagrant/${local.box_name}.box
  EOF

}

data "external-raw" "disklabel" {
  program = ["./scripts/packer_external_disklabel.sh"]
  query   = local.disklabel_file
}

data "external-raw" "autoinstall" {
  program = ["./scripts/packer_external_autoinstall.sh"]
  query   = <<-EOF
    ssh_public_key=${chomp(file("${local.dir_vagrant_keys}/vagrant.pub.rsa"))}
    server_directory=mirror/${var.obsd_version}/${var.obsd_arch}
    set_names=${local.set_names}
    run_x=${local.run_x}
    default_com0=${local.default_com0}
  EOF
}


source "qemu" "virt_machine" {
  vm_name = local.box_name

  qemu_binary  = local.qemu_binary
  machine_type = local.qemu_machine
  accelerator  = local.qemu_accel

  efi_boot          = true
  efi_drop_efivars  = true
  efi_firmware_code = local.qemu_efi_code
  efi_firmware_vars = local.qemu_efi_vars
  use_pflash        = false

  output_directory = "./output/qemu"
  http_directory   = local.dir_httproot

  iso_url      = "file://${abspath(local.dir_installmirror)}/${local.iso_filename}"
  iso_checksum = "sha256:${local.iso_checksum}"

  disk_interface = "virtio"
  cpus           = 2
  memory         = "1024"

  disk_size        = "${var.disk_size_gb}G"
  disk_compression = false
  skip_compaction  = true
  format           = "raw"

  communicator         = "ssh"
  ssh_username         = "root"
  ssh_private_key_file = "${local.dir_vagrant_keys}/vagrant.key.rsa"

  headless     = true
  vnc_port_max = 5923
  vnc_port_min = 5923

  boot_command = [
    "s<enter><wait2s>",
    "ifconfig vio0 autoconf<enter><wait5s>",
    "ftp -o i http://{{ .HTTPIP }}:{{ .HTTPPort }}/i && sh -x i {{ .HTTPIP }}:{{ .HTTPPort }}<enter>",
    "<wait2m10s>",
  ]
  boot_key_interval = "50ms"
  boot_wait         = "20s"

  shutdown_command = "shutdown -p now"
}

# hcp_packer_registry {
#   bucket_name = local.packer_bucket_name
#
#   bucket_labels = {
#     "os-version"  = var.obsd_version
#     "os-arch"     = var.obsd_arch
#     "img-variant" = var.obsd_img_variant
#   }
#
#   build_labels = {
#     "build-time"   = timestamp()
#     "build-source" = basename(path.cwd)
#     "box-version"  = var.box_version
#   }
# }

build {
  name = "openbsd-box"

  sources = ["source.qemu.virt_machine"]

  provisioner "shell" {
    name   = "syspatch"
    script = "${path.root}/scripts/image_syspatch.sh"
  }

  provisioner "shell" {
    name   = "doas"
    script = "${path.root}/scripts/image_setup_doas.sh"
  }

  provisioner "shell" {
    name = "source"
    env = {
      PACKER_SETUP_PORTS  = var.obsd_img_variant == "ports" ? "1" : "0"
      PACKER_SETUP_SOURCE = var.obsd_img_variant == "source" ? "1" : "0"
    }
    script = "${path.root}/scripts/image_setup_source.sh"
  }

  provisioner "shell" {
    name   = "installurl"
    script = "${path.root}/scripts/image_setup_installurl.sh"
  }

  provisioner "shell" {
    env = {
      PACKER_SETUP_CLOUDINIT = var.obsd_img_variant == "cloud" ? "1" : "0"
    }
    name   = "cloud-init"
    script = "${path.root}/scripts/image_setup_cloud_init.sh"
  }

  provisioner "shell" {
    name   = "sysprep"
    script = "${path.root}/scripts/image_sysprep.sh"
  }



  post-processors {
    post-processor "vagrant" {
      architecture         = var.obsd_arch
      keep_input_artifact  = true
      compression_level    = 9
      provider_override    = "libvirt"
      vagrantfile_template = "${path.root}/templates/Vagrantfile.base.rb"
      output               = "./output/vagrant/${local.box_name}.box"
    }

    // post-processor "shell-local" {
    //   inline = [local.register_box_cmd]
    // }

    // post-processor "vagrant-registry" {
    //   box_tag      = local.vagrant_box_tag
    //   version      = var.box_version
    //   architecture = var.obsd_arch
    // }
  }


}
