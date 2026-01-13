variable "obsd_arch" {
  type        = string
  description = "Architecture (amd64|arm64)"

  validation {
    condition     = (var.obsd_arch == "amd64" || var.obsd_arch == "arm64")
    error_message = "Valid arches: amd64 arm64."
  }
}

variable "obsd_version" {
  type        = string
  description = "OpenBSD release version"
  validation {
    condition     = can(regex("[0-9]+.[0-9]+", var.obsd_version))
    error_message = "Variable obsd_version should be formatted as X.Y."
  }
}

variable "img_variant" {
  type        = string
  description = "Image variant to build"

  validation {
    condition     = contains(["base", "nox", "full", "ports", "src", "cloud"], var.img_variant)
    error_message = "Valid variants: base nox full ports src cloud."
  }
}

variable "disk_size_gb" {
  type        = number
  description = "Root size in GB"
}

variable "box_version" {
  type        = string
  description = "Semantic version of this box"
}

variable "qemu_use_uefi" {
  type        = bool
  description = "Whether to use UEFI for booting (implies GPT disk partitioning)"
}

variable "qemu_smp" {
  type        = number
  description = "Number of CPUs for VM"
}

variable "hcp_upload" {
  type        = bool
  description = "Whether to upload artifacts to hashicorp cloud"
}

variable "vagrant_box" {
  type        = bool
  description = "Build image for Vagrant"
}

variable "packer_dir_http" {
  type        = string
  description = "Root directory for packer HTTP server"
}

variable "packer_dir_vagrantkeys" {
  type        = string
  description = "Directory for base vagrant keys"
}

variable "packer_dir_output_qemu" {
  type        = string
  description = "Qemu output dir"
}

variable "packer_dir_output_vagrant" {
  type        = string
  description = "Vagrant output dir"
}