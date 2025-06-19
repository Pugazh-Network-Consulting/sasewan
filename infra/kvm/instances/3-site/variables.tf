#
variable "username" {
  type = string
}

variable "pool_path" {
  type = string
  default = "/var/lib/libvirt/images"
}

variable "server_ip" {
  type = string
}

variable "ubuntu_base_path" {
  type = string
  default = "https://mega.nz/file/m9oUwIAI#SQVBXVY8geqy5_hpghX3fkTDNbMse_-uo2JTxe0_S-s"
}

variable "ubuntu_fwedge_path" {
  type = string
  default = "https://mega.nz/file/L9AmSAxY#dtBXmiqnSXTKgLBYbBL4AieH-35Wp9P9zKVkMk9wjPs"
}

variable "ssh_key_file" {
  type = string
}

variable "client_instance_count" {
  type = number
  default = 3
}

variable "mgmt_network" {
  description = "Management IP with Netmask"
}

variable "edge_instance_count" {
  type = number
  default = 3
}

variable "repo" {
  description = "Repository for testing"
  default = "setup"
}

variable "edge_version" {
  description = "version string of edge"
}

variable "token" {
  description = "token of the organization"
}

variable "access_key" {
  description = "access key of the organization"
}
