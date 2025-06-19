variable "username" {
  type = string 
  default = "ubuntu"
}

variable "ssh_key_file" {
  type = string
}

variable "ubuntu_cloud_image" {
  type = string
  default = "https://cloud-images.ubuntu.com/focal/20250605/focal-server-cloudimg-amd64.img"
}

variable "ubuntu_image_checksum" {
  type = string
  default = "b55942306988d925e839ab55bdb2e06ff450a900dfd4060ae801c012e2f39b77"
}

variable "server_ip" {
  type = string
}

variable "mgmt_network" {
  type = string
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
  
  source "libvirt" "focal" {
    libvirt_uri = "qemu+ssh://ubuntu@${var.server_ip}/system?keyfile=${var.ssh_key_file}&no_verify=1"
  
    vcpu   = 2
    memory = 1024
  
    network_interface {
      type  = "bridge"
      bridge = "br-mgmt"
    }
  
    communicator {
      communicator              = "ssh"
      ssh_host                  = "${var.server_ip}"
      ssh_port                  = "1011"
      ssh_username              = "ubuntu"
      #ssh_password              = "flexiwan"
      ssh_private_key_file      = data.sshkey.install.private_key_path
      ssh_file_transfer_method  = "scp"
    }
    network_address_source = "agent"
  
    volume {
      name  = "focal-image"
      alias = "artifact"
      pool = "default"
      source {
        type     = "external"
        # With newer releases, the URL and the checksum can change.
        urls     = ["${var.ubuntu_cloud_image}"]
        checksum = "${var.ubuntu_image_checksum}"
      }
      capacity   = "5G"
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
    sources = ["source.libvirt.focal"]
    provisioner "shell" {
      inline = [
        "echo The domain has started and became accessible",
        "sudo ip addr show",
        #"sudo ip -br a",
        #"sudo ip route show",
        #"sudo cat /etc/resolv.conf",
        #"sudo dig @127.0.0.53 www.google.com",
        "sudo apt update",
        "sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade",
        "sudo echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
        "sudo apt-get install -y -qq net-tools curl wget iperf iperf3 fping traceroute iptables-persistent",
        "sudo sed -i -e 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/g' /etc/default/grub",
        "sudo update-grub",
        "sudo rm -fr /var/lib/cloud/*",
        #"ip -br a",
      ]
    }
    post-processor "manifest" {
      output = "ubuntu-focal-manifest.json"
      strip_path = false 
    }
  }
