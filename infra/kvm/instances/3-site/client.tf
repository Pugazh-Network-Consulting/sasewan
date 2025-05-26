resource "libvirt_pool" "client" {
  count = var.client_instance_count
  name = "b${count.index + 1}-client1"
  type = "dir"
  path = "${var.pool_path}/b${count.index + 1}-client1"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "client" {
  count = var.client_instance_count
  name   = "b${count.index + 1}-client1"
  pool   = "${libvirt_pool.client["${count.index}"].name}"
  source =  "${var.ubuntu_base_path}"
  format = "qcow2"
}

data "template_file" "user_data" {
  count = var.client_instance_count
  template = file("${path.module}/client-user-data.yaml")

  vars = {
    "hostname" = "b${count.index + 1}-client1"
  }
}

data "template_file" "network_config" {
  count = var.client_instance_count
  template = file("${path.module}/client-network-config.yaml")

  vars = {
    "mgmt_ip" = cidrhost("${var.mgmt_network}", "${11 + count.index}") 
    "lan_ip" = cidrhost("10.${count.index + 1}.1.0/24", "10") 
    "netmask" = "24"
    "gateway" = cidrhost("10.${count.index + 1}.1.0/24", "1")
    "nameserver" = "8.8.8.8"
  }
}

resource "libvirt_network" "mgmt_network" {
  count = var.client_instance_count
  name  = "c${count.index + 1}-mgmt"
  mode  = "bridge"
  autostart = true
  bridge = "br-mgmt"
}

resource "libvirt_network" "lan_network" {
  count = var.client_instance_count
  #name = "b${count.index + 1}-client1"
  name = "c1-edge${count.index + 1}"
  mode = "bridge"
  bridge = "c1-edge${count.index + 1}"
  autostart = true
}

# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
resource "libvirt_cloudinit_disk" "seed" {
  count          = var.client_instance_count
  name           = "seed.iso"
  user_data      = "${data.template_file.user_data["${count.index}"].rendered}"
  network_config = "${data.template_file.network_config["${count.index}"].rendered}"
  pool           = "${libvirt_pool.client["${count.index}"].name}"
}

# Create the machine
resource "libvirt_domain" "client" {
  count  = var.client_instance_count
  name   = "b${count.index + 1}-client1"
  memory = "1024"
  vcpu   = 2

  cloudinit = "${libvirt_cloudinit_disk.seed["${count.index}"].id}"

    network_interface {
    network_id = "${libvirt_network.mgmt_network["${count.index}"].id}"
    network_name = "${libvirt_network.mgmt_network["${count.index}"].name}"
    addresses = [cidrhost("${var.mgmt_network}", "${11 + count.index}")]
  }

    network_interface {
    network_id = "${libvirt_network.lan_network["${count.index}"].id}"
  }

  disk {
    volume_id = "${libvirt_volume.client["${count.index}"].id}"
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
 