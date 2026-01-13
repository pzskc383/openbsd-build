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
  program = [
    "${local.dir_scripts}/packer_external_vagrant_keys.sh",
    local.dir_vagrantkeys
  ]
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
