data "sshkey" "packer" {
  name = "packer"
  type = "ed25519"
}

data "password" "root" {
  hash = "sha512"
}

data "password" "user" {
  hash = "sha512"
}

data "external" "vagrant_keys" {
  program = ["./scripts/packer_external_vagrant_keys.sh", abspath(var.packer_dir_vagrantkeys)]
}

locals {
  sets = {
    file_sets = {
      base = "-* bsd bsd.rd bsd.mp base*"
      nox  = "-* bsd bsd.rd bsd.mp base* man* comp* game*"
      full = "-* bsd bsd.rd bsd.mp base* man* comp* game* xbase* xfont* xshare* xserv*"
    }
    provisioner_scripts = {
      base  = ["syspatch", "doas", "installurl", "sysprep"]
      src   = ["syspatch", "doas", "builder", "source", "installurl", "sysprep"]
      ports = ["syspatch", "doas", "builder", "ports", "source", "installurl", "sysprep"]
      cloud = ["syspatch", "doas", "installurl", "cloud_init", "sysprep"]
    }
  }

  definitions = {
    variants = {
      base = {
        sets         = local.sets.file_sets.base
        provisioners = local.sets.provisioner_scripts.base
        disklabel    = "base"
        suffix       = "-base"
      }
      nox = {
        sets         = local.sets.file_sets.nox
        provisioners = local.sets.provisioner_scripts.base
        disklabel    = "base"
        suffix       = "-nox"
      }
      full = {
        sets         = local.sets.file_sets.full
        provisioners = local.sets.provisioner_scripts.base
        disklabel    = "base"
        suffix       = ""
      }
      src = {
        sets         = local.sets.file_sets.full
        provisioners = local.sets.provisioner_scripts.src
        disklabel    = "src"
        suffix       = "-src"
      }
      ports = {
        sets         = local.sets.file_sets.full
        provisioners = local.sets.provisioner_scripts.ports
        disklabel    = "ports"
        suffix       = "-ports"
      }
      cloud = {
        sets         = local.sets.file_sets.nox
        provisioners = local.sets.provisioner_scripts.cloud
        disklabel    = "cloud"
        suffix       = "-cloud"
      }
    }

    arches = {
      arm64 = {
        qemu_binary  = "qemu-system-aarch64"
        qemu_machine = "virt"
        qemu_accel   = "tcg"
        efi_code     = "/usr/share/edk2/aarch64/QEMU_EFI.fd"
        efi_vars     = "/usr/share/edk2/aarch64/QEMU_VARS.fd"
      }
      amd64 = {
        qemu_binary  = "qemu-system-x86_64"
        qemu_machine = "q35"
        qemu_accel   = "kvm"
        efi_code     = "/usr/share/OVMF/OVMF_CODE.fd"
        efi_vars     = "/usr/share/OVMF/OVMF_VARS.fd"
      }
    }
  }

  short_version  = replace(var.obsd_version, ".", "")
  image_basename = "openbsd${local.short_version}"

  dir_installmirror = "${var.packer_dir_http}/mirror/${var.obsd_version}/${var.obsd_arch}"

  qemu_binary  = local.definitions.arches[var.obsd_arch].qemu_binary
  qemu_machine = local.definitions.arches[var.obsd_arch].qemu_machine
  qemu_accel   = local.definitions.arches[var.obsd_arch].qemu_accel

  set_names = local.definitions.variants[var.img_variant].sets

  disklabel_variant = local.definitions.variants[var.img_variant].disklabel
  disklabel_file    = "${path.root}/templates/disklabel.${local.disklabel_variant}.txt"

  iso_filename = "cd${local.short_version}.iso"

  headless     = (var.img_variant == "base" || var.img_variant == "nox")
  run_x        = local.headless ? "yes" : "no"
  default_com0 = "no"

  iso_checksum_parts = [
    for l in split("\n", file("${local.dir_installmirror}/SHA256")) :
    split(" ", l)[3] if strcontains(l, local.iso_filename)
  ]
  iso_checksum = local.iso_checksum_parts[0]

  vagrant_default_key_private = data.external.vagrant_keys.result["ed25519_private"]

  image_user_name       = var.vagrant_box ? "vagrant" : "user"
  image_user_password   = var.vagrant_box ? "vagrant" : data.password.user.crypt
  image_root_password   = var.vagrant_box ? "vagrant" : data.password.root.crypt
  image_root_sshpubkey  = var.vagrant_box ? data.external.vagrant_keys.result["ed25519_public"] : data.sshkey.packer.public_key
  image_root_sshprivkey = var.vagrant_box ? data.external.vagrant_keys.result["ed25519_private"] : data.sshkey.packer.private_key_path
}

data "external-raw" "disklabel" {
  program = ["./scripts/packer_external_disklabel.sh"]
  query   = local.disklabel_file
}

data "external-raw" "autoinstall" {
  program = ["./scripts/packer_external_autoinstall.sh"]
  query   = <<-EOF
    ssh_public_key=${local.image_root_sshpubkey}
    server_directory=mirror/${var.obsd_version}/${var.obsd_arch}
    set_names=${local.set_names}
    run_x=${local.run_x}
    default_com0=${local.default_com0}
  EOF


}
