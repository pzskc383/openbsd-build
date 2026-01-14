source "qemu" "openbsd" {
  efi_boot         = var.qemu_use_uefi
  efi_drop_efivars = true
  use_pflash       = false

  http_directory = local.dir_http

  disk_interface = "virtio"
  cpus           = var.qemu_smp
  memory         = var.qemu_memory

  disk_size        = "${var.disk_size_gb}G"
  disk_compression = false
  skip_compaction  = true
  format           = "raw"

  communicator         = "ssh"
  ssh_username         = "root"
  ssh_private_key_file = local.image_root_sshprivkey

  headless          = true
  boot_key_interval = "50ms"
  boot_wait         = "20s"

  shutdown_command = "shutdown -p now"
}

build {
  name = "openbsd"

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

      vnc_port_min = 5920 + index(keys(local.builder_variants), source.key)
      vnc_port_max = 5920 + index(keys(local.builder_variants), source.key)

      output_directory = "${local.dir_output_qemu}/${source.key}"

      iso_url      = "file://${local.httproot_meta[source.key]["iso_path"]}"
      iso_checksum = "sha256:${local.httproot_meta[source.key]["iso_checksum"]}"

      boot_command = [
        "s<enter><wait2s>",
        "ifconfig vio0 autoconf<enter><wait5s>",
        "ftp -o i http://{{ .HTTPIP }}:{{ .HTTPPort }}/i && sh -x i {{ .HTTPIP }}:{{ .HTTPPort }} ${source.key}<enter>",
        "<wait2m10s>",
      ]
    }
  }


  error-cleanup-provisioner "shell-local" {
    name   = "cleanup"
    inline = ["rm -rf ${local.dir_output_qemu} ${local.dir_output_vagrant}"]
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
      keep_input_artifact  = true
      compression_level    = 9
      provider_override    = "libvirt"
      vagrantfile_template = "${local.dir_templates}/Vagrantfile.base.rb"
      output               = "${local.dir_output_vagrant}/${source.name}.box"
    }
  }
}
