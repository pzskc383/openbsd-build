locals {
  definitions = {
    file_sets = {
      base = "-* bsd bsd.rd bsd.mp base*"
      nox  = "-* bsd bsd.rd bsd.mp base* man* comp* game*"
      full = "-* bsd bsd.rd bsd.mp base* man* comp* game* xbase* xfont* xshare* xserv*"
    }
  }

  image_variants = {
    base = {
      sets      = local.definitions.file_sets.base
      disklabel = "base"
      suffix    = "-base"
    }
    nox = {
      sets      = local.definitions.file_sets.nox
      disklabel = "base"
      suffix    = "-nox"
    }
    full = {
      sets      = local.definitions.file_sets.full
      disklabel = "base"
      suffix    = ""
    }
    src = {
      sets      = local.definitions.file_sets.full
      disklabel = "src"
      suffix    = "-src"
    }
    ports = {
      sets      = local.definitions.file_sets.full
      disklabel = "ports"
      suffix    = "-ports"
    }
    cloud = {
      sets      = local.definitions.file_sets.nox
      disklabel = "cloud"
      suffix    = "-cloud"
    }
  }

  image_arches = {
    arm64 = {
      qemu_binary  = "qemu-system-aarch64"
      qemu_machine = "virt"
      qemu_accel   = "tcg"
      efi_code     = "/usr/share/edk2/aarch64/QEMU_EFI.fd"
      efi_vars     = "/usr/share/edk2/aarch64/QEMU_VARS.fd"
      disabled     = true
    }
    amd64 = {
      qemu_binary  = "qemu-system-x86_64"
      qemu_machine = "q35"
      qemu_accel   = "kvm"
      efi_code     = "/usr/share/OVMF/OVMF_CODE.fd"
      efi_vars     = "/usr/share/OVMF/OVMF_VARS.fd"
    }
  }

  builder_variants = {
    for k in setproduct(keys(local.image_arches), keys(local.image_variants)) :
    "${k[0]}.${k[1]}" => merge(
      local.image_arches[k[0]],
      local.image_variants[k[1]]
    ) if(!try(k[0].disabled, false) && !try(k[1].disabled, false))
  }

  short_version  = replace(var.obsd_version, ".", "")
  image_basename = "openbsd${local.short_version}"

  dir_http           = abspath("${path.root}/${var.packer_dir_http}")
  dir_vagrantkeys    = abspath("${path.root}/${var.packer_dir_vagrantkeys}")
  dir_templates      = abspath("${path.root}/${var.packer_dir_templates}")
  dir_scripts        = abspath("${path.root}/${var.packer_dir_scripts}")
  dir_output_qemu    = abspath("${path.root}/${var.packer_dir_output_qemu}")
  dir_output_vagrant = abspath("${path.root}/${var.packer_dir_output_vagrant}")
  dir_mirror         = abspath("${path.root}/${var.packer_dir_ftp_mirror}")

  iso_filename = "cd${local.short_version}.iso"


  image_user_name       = var.vagrant_box ? "vagrant" : "user"
  image_user_password   = var.vagrant_box ? "vagrant" : data.password.user.crypt
  image_root_password   = var.vagrant_box ? "vagrant" : data.password.root.crypt
  image_root_sshpubkey  = var.vagrant_box ? data.external.vagrant_keys.result["ed25519_public"] : data.sshkey.packer.public_key
  image_root_sshprivkey = var.vagrant_box ? data.external.vagrant_keys.result["ed25519_private"] : data.sshkey.packer.private_key_path
}