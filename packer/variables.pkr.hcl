variable "obsd_version" {
  type        = string
  description = "OpenBSD release version"
  validation {
    condition     = can(regex("[0-9]+.[0-9]+", var.obsd_version))
    error_message = "Variable obsd_version should be formatted as X.Y."
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

variable "packer_dir_templates" {
  type        = string
  description = "Directory for templates"
}

variable "packer_dir_scripts" {
  type        = string
  description = "Directory for scripts"
}

variable "packer_dir_output_qemu" {
  type        = string
  description = "Qemu output dir"
}

variable "packer_dir_output_vagrant" {
  type        = string
  description = "Vagrant output dir"
}