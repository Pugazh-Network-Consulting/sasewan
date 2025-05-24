#
variable "username" {
  type = string
  default = "ubuntu"
}

variable "pool_path" {
  type = string
  default = "/var/lib/libvirt/images"
}

variable "server_ip" {
  type = string
  default = "34.82.84.228"
}

variable "ubuntu_base_path" {
  type = string
  #default = "https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
  default = "https://sandbox.flexiwan.com/Utils/base_image_focal_regression_tests.qcow2"
}

variable "ssh_key_file" {
  type = string
  default = "/home/ubuntu/pugazht/flexiwan-regression-tests_ssh_key"
}

variable "mgmt_network" {
  description = "Management IP with Netmask"
  default = "10.20.0.2/24"
}

variable "org_token" {
  description = "Organization token"
  default = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJvcmciOiI2NDJlNzI0OTRiOWVhMjBiOWM1YzY2NjUiLCJhY2NvdW50IjoiNjBlMmE1YmUzNjU1M2U1MWFhMjIzNzdhIiwic2VydmVyIjoiaHR0cHM6Ly9hcHBxYTAxLmZsZXhpd2FuLmNvbTo0NDMiLCJpYXQiOjE2ODk1NzkyNjd9.kM9pRUZMLoM1gxBsLiWxzXocQFycU6eZcWisP6IKJhQ"
}
