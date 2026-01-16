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

data "external-raw" "cleanup_output" {
  program = [
    "${local.dir_scripts}/packer_external_cleanup_output.sh",
    local.dir_output_qemu, local.dir_output_vagrant
  ]
}

locals {
  dummy_input = data.external-raw.cleanup_output.result
}

data "external" "vagrant_keys" {
  program = [
    "${local.dir_scripts}/packer_external_vagrant_keys.sh",
    local.dir_vagrantkeys
  ]
}

locals {
  httproot_input_vars = concat(
    [
      "config httproot ${local.dir_http}",
      "config mirror ${local.dir_mirror}",
      "config templates ${local.dir_templates}",
      "config version ${var.obsd_version}",
      "config ssh_pubkey ${local.image_root_sshpubkey}",
    ],
    flatten([
      for tag, vars in local.builder_variants : [
        "${tag} sets ${vars.sets}",
        "${tag} disklabel ${vars.disklabel}",
      ]
    ])
  )

  httproot_lines = compact(split("\n", data.external-raw.httproot.result))
  httproot_tags  = distinct([for line in local.httproot_lines : element(split(" ", line), 0)])
  httproot_meta = {
    for tag in local.httproot_tags :
    tag => {
      for line in local.httproot_lines :
      element(split(" ", line), 1) => join(" ", slice(split(" ", line), 2, length(split(" ", line))))
      if element(split(" ", line), 0) == tag
    }
  }

}

data "external-raw" "httproot" {
  program = ["./scripts/packer_external_httproot.sh"]
  query   = "${join("\n", local.httproot_input_vars)}\n"
}
