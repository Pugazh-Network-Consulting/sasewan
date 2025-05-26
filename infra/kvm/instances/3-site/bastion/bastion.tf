resource "libvirt_pool" "bastion" {
  name = "bastion"
  type = "dir"
  path = "${var.pool_path}/bastion"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "bastion" {
  name   = "bastion"
  pool   = "${libvirt_pool.bastion.name}"
  source = "${var.ubuntu_base_path}"
  format = "qcow2"
}

data "template_file" "bastion_user_data" {
  template = file("bastion-user-data.yaml")

  vars = {
    "hostname" = "bastion"
    "token" = "${var.org_token}"
  }
}

data "template_file" "bastion_network_config" {
  template = file("bastion-network-config.yaml")

  vars = {
    "mgmt_ip" = cidrhost("${var.mgmt_network}", "101") 
    "lan_ip" = cidrhost("172.16.1.0/24", "10")
    "bastion1_ip" = cidrhost("111.1.1.0/24", "1")
    "bastion2_ip" = cidrhost("112.1.1.0/24", "1")
    "bastion1_gateway" = cidrhost("111.1.1.0/24", "10")
    "bastion2_gateway" = cidrhost("112.1.1.0/24", "10")
    "netmask" = "24"
    "gateway" = split("/", "${var.mgmt_network}")[0]
    "nameserver" = "8.8.8.8"
  }
}

resource "libvirt_network" "bastion_mgmt_network" {
  name  = "br-mgmt"
  mode  = "bridge"
  autostart = true
  bridge = "br-mgmt"
}

resource "libvirt_network" "bastion_cr_network" {
  name  = "br-cr"
  mode  = "bridge"
  autostart = true
  bridge = "br-cr"
}

# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
resource "libvirt_cloudinit_disk" "bh_seed" {
  name           = "seed.iso"
  user_data      = "${data.template_file.bastion_user_data.rendered}"
  network_config = "${data.template_file.bastion_network_config.rendered}"
  pool           = "${libvirt_pool.bastion.name}"
}

# Create the machine
resource "libvirt_domain" "bastion" {
  name   = "bastion"
  memory = "1024"
  vcpu   = 2

  cloudinit = "${libvirt_cloudinit_disk.bh_seed.id}"

  network_interface {
    network_id = "${libvirt_network.bastion_mgmt_network.id}"
    addresses = [cidrhost("${var.mgmt_network}", "31")]
    network_name = "${libvirt_network.bastion_mgmt_network.name}"
  }

  network_interface {
    network_id = "${libvirt_network.bastion_cr_network.id}"
  }

  disk {
    volume_id = "${libvirt_volume.bastion.id}"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }

}
 