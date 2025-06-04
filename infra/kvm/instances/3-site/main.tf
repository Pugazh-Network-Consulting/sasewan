terraform {
 #required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      #version = "0.7.1"
     }
  }
}

# instance the provider
provider "libvirt" {
  uri = "qemu+ssh://${var.username}@${var.server_ip}/system?keyfile=${var.ssh_key_file}"
}
