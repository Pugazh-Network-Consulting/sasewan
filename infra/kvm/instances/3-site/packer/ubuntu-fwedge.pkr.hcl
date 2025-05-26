variable "username" {
  type = string 
}

variable "ssh_key_file" {
  type = string
}

variable "ubuntu_cloud_image" {
  type = string
  #default = "https://sandbox.flexiwan.com/Utils/focal.6.3.2-testing.console.bios.qcow2"
  default = "https://cloud-images.ubuntu.com/focal/20250403/focal-server-cloudimg-amd64.img"
}

variable "ubuntu_image_checksum" {
  type = string
  default = "dbc3565f827265db24b9bee2d5ab74ccbc7b1fdc57d5bb266f032e7ce531a70c"
  #default = "b358f7d6c092e700fbfe0a43401f8cb5395a526807fd85373e661a4b2a9f8fa5"

}

variable "server_ip" {
  type = string
}

variable "mgmt_network" {
  type = string
}

variable "edge_version" {
  type = string
  default = "latest"
}

variable "repo" {
  type = string 
  default = "setup"
}

packer {
    required_plugins {
        sshkey = {
        version = ">= 1.1.0"
        source = "github.com/ivoronin/sshkey"
      }
      libvirt = {
        version = ">= 0.5.0"
        source  = "github.com/thomasklein94/libvirt"
      }
    }
  }

  data "sshkey" "install" {
    
  }

   locals {
    user_data_part = {
      runcmd = [
        ["sed" , "-i", "-e", "$aAllowUsers", "ubuntu", "/etc/ssh/sshd_config" ],
        ["sed" , "-i", "-e", "/^PasswordAuthentication no/s/^.*$/PasswordAuthentication yes/", "/etc/ssh/sshd_config" ],
        ["service", "ssh" , "restart" ],
      ]
      ssh_authorized_keys = [
        data.sshkey.install.public_key
      ]
    }

    network_config_part = {
      version = 2
        ethernets = {
          eth = {
            match = {
              name = "ens*"
            }
            addresses = [ join("/", [cidrhost("${var.mgmt_network}", 101), "24"]) ]
            gateway4 = split("/", "${var.mgmt_network}")[0]
            nameservers = {
              search = [ "google.internal" ]
              addresses = [ "8.8.8.8" ]
            }
          }
        }
    }  
    
  }
  
  source "libvirt" "edge" {
    libvirt_uri = "qemu+ssh://ubuntu@${var.server_ip}/system?keyfile=${var.ssh_key_file}&no_verify=1"
  
    vcpu   = 4
    memory = 4096
  
    network_interface {
      type  = "bridge"
      bridge = "br-mgmt"
    }
  
    communicator {
      communicator          = "ssh"
      ssh_host              = "${var.server_ip}"
      ssh_port              = "1011"
      ssh_username          = "ubuntu"
      ssh_private_key_file  = data.sshkey.install.private_key_path
      ssh_file_transfer_method = "scp"
    }
    network_address_source = "agent"
  
    volume {
      name  = "edge-image"
      alias = "artifact"
      pool = "default"
      source {
        type     = "external"
        # With newer releases, the URL and the checksum can change.
        urls     = ["${var.ubuntu_cloud_image}"]
        checksum = "${var.ubuntu_image_checksum}"
      }
      capacity   = "20G"
      bus        = "sata"
      format     = "qcow2"
    }

    volume {
      name = "cloud-init"
      source {
        type = "cloud-init"
        user_data = format("#cloud-config\n%s", jsonencode(local.user_data_part))
        network_config = jsonencode(local.network_config_part)
      }
      bus        = "sata"
    }
    shutdown_mode = "acpi"
  }
  
  build {
    sources = ["source.libvirt.edge"]
    provisioner "shell" {
      inline = [
        "echo The domain has started and became accessible",
        "ip route show",
        #"sudo apt-get purge -y flexiwan-router",
        "sudo apt update",
        "sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade",
        "sudo echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
        "sudo apt-get install -y -qq net-tools curl wget traceroute",
        "curl -sL https://deb.flexiwan.com/${var.repo} | sudo bash -",
        "sudo apt-get install -y flexiwan-router",
        "sudo sed -i -e 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/g' /etc/default/grub",
        "sudo update-grub",
        "sudo rm -fr /var/lib/cloud/*",
        "ip -br a",
      ]
    }
    post-processor "manifest" {
      output = "ubuntu-fwedge-manifest.json"
      strip_path = false 
    }
  }
