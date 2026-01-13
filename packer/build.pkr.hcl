source "qemu" "openbsd" {
  qemu_binary  = local.qemu_binary
  machine_type = local.qemu_machine
  accelerator  = local.qemu_accel

  efi_boot          = true
  efi_drop_efivars  = true
  efi_firmware_code = var.obsd_arch == "amd64" ? "/usr/share/OVMF/OVMF_CODE.fd" : "/usr/share/edk2/aarch64/QEMU_EFI.fd"
  efi_firmware_vars = var.obsd_arch == "amd64" ? "/usr/share/OVMF/OVMF_VARS.fd" : "/usr/share/edk2/aarch64/QEMU_VARS.fd"
  use_pflash        = false

  output_directory = var.packer_dir_output_qemu
  http_directory   = var.packer_dir_http

  iso_url      = "file://${abspath(local.dir_installmirror)}/${local.iso_filename}"
  iso_checksum = "sha256:${local.iso_checksum}"

  disk_interface = "virtio"
  cpus           = var.qemu_smp
  memory         = "1024"

  disk_size        = "${var.disk_size_gb}G"
  disk_compression = false
  skip_compaction  = true
  format           = "raw"

  communicator         = "ssh"
  ssh_username         = "root"
  ssh_private_key_file = local.image_root_sshprivkey

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

build {
  name = "qemu-openbsd"

  dynamic "source" {
    for_each = local.definitions.variants
    labels   = ["source.qemu.openbsd"]

    content {
      name    = source.key
      vm_name = "${local.image_basename}${source.value.suffix}"
    }
  }

  #sources = ["qemu.openbsd"]


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

  dynamic hcp_packer_registry {
    for_each = var.hcp_upload ? [1] : []
    content {
      bucket_name = local.packer_bucket_name

      bucket_labels = {
        "version" = var.obsd_version
        "arch"    = var.obsd_arch
        "variant" = var.img_variant
      }
    }
  }


}
