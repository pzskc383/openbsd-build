source "qemu" "openbsd" {
  efi_boot         = var.qemu_use_uefi
  efi_drop_efivars = true
  use_pflash       = false

  output_directory = local.dir_output_qemu
  http_directory   = local.dir_http

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

  headless = true
  #vnc_port_min = 5923
  #vnc_port_max = 5923

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
    for_each = local.builder_variants
    labels   = ["source.qemu.openbsd"]

    content {
      name              = source.key
      vm_name           = "${local.image_basename}${source.value.suffix}"
      efi_firmware_code = source.value.efi_code
      efi_firmware_vars = source.value.efi_vars
      qemu_binary       = source.value.qemu_binary
      machine_type      = source.value.qemu_machine
      accelerator       = source.value.qemu_accel
    }
  }

  provisioner "shell" {
    name   = "syspatch"
    script = "${local.dir_scripts}/image_syspatch.sh"
  }

  provisioner "shell" {
    name   = "doas"
    script = "${local.dir_scripts}/image_doas.sh"
  }

  provisioner "shell" {
    name   = "builder"
    script = "${local.dir_scripts}/image_builder.sh"
    only   = ["source.qemu.src", "source.qemu.ports"]
  }

  provisioner "shell" {
    name   = "src"
    script = "${local.dir_scripts}/image_source.sh"
    only   = ["source.qemu.src"]
  }

  provisioner "shell" {
    name   = "ports"
    script = "${local.dir_scripts}/image_ports.sh"
    only   = ["source.qemu.src", "source.qemu.ports"]
  }

  provisioner "shell" {
    name   = "cloud_init"
    script = "${local.dir_scripts}/image_cloud_init.sh"
    only   = ["source.qemu.cloud"]
  }

  provisioner "shell" {
    name   = "sysprep"
    script = "${local.dir_scripts}/image_sysprep.sh"
  }

  provisioner "shell" {
    name   = "installurl"
    script = "${local.dir_scripts}/image_installurl.sh"
  }



  post-processors {
    post-processor "vagrant" {
      architecture         = var.obsd_arch
      keep_input_artifact  = true
      compression_level    = 9
      provider_override    = "libvirt"
      vagrantfile_template = "${local.dir_templates}/Vagrantfile.base.rb"
      output               = "${local.dir_output_vagrant}/${source.name}.box"
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
