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
}

variable "ubuntu_fwedge_path" {
  type = string
}

variable "ssh_key_file" {
  type = string
}

variable "client_instance_count" {
  type = number
  default = 2
}

variable "mgmt_network" {
  description = "Management IP with Netmask"
}

variable "edge_instance_count" {
  type = number
  default = 2
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
