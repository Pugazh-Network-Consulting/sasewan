resource "libvirt_pool" "core" {
  name = "core"
  type = "dir"
  path = "${var.pool_path}/core"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "core" {
  name   = "core"
  pool   = "${libvirt_pool.core.name}"
  source =  "${var.ubuntu_base_path}"
  format = "qcow2"
}

data "template_file" "cr_user_data" {
  template = file("${path.module}/cr-user-data.yaml")

  vars = {
    "hostname" = "core"
  }
}

data "template_file" "cr_network_config" {
  template = file("${path.module}/cr-network-config.yaml")

  vars = {
    "mgmt_ip" = cidrhost("${var.mgmt_network}", "31") 
    "core1_ip" = cidrhost("111.1.1.0/24", "1")
    "core2_ip" = cidrhost("112.1.1.0/24", "1")
    "core1_gateway" = cidrhost("111.1.1.0/24", "10")
    "core2_gateway" = cidrhost("112.1.1.0/24", "10")
    "edge1_wan1_ip" = "101.1.1.0/24"
    "edge2_wan1_ip" = "101.2.1.0/24"
    # "edge3_wan1_ip" = "101.3.1.0/24"
    "edge1_wan2_ip" = "102.1.1.0/24"
    "edge2_wan2_ip" = "102.2.1.0/24"
    # "edge3_wan2_ip" = "102.3.1.0/24"
    "netmask" = "24"
    "gateway" = split("/", "${var.mgmt_network}")[0]
    "nameserver" = "8.8.8.8"
  }
}

resource "libvirt_network" "cr_mgmt_network" {
  name  = "cr-mgmt"
  mode  = "bridge"
  autostart = true
  bridge = "br-mgmt"
}

resource "libvirt_network" "cr1_cr_network" {
  name  = "cr1-cr"
  mode  = "bridge"
  autostart = true
  bridge = "cr1-cr"
}

resource "libvirt_network" "cr2_cr_network" {
  name  = "cr2-cr"
  mode  = "bridge"
  autostart = true
  bridge = "cr2-cr"
}

# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
resource "libvirt_cloudinit_disk" "cr_seed" {
  name           = "seed.iso"
  user_data      = "${data.template_file.cr_user_data.rendered}"
  network_config = "${data.template_file.cr_network_config.rendered}"
  pool           = "${libvirt_pool.core.name}"
}

# Create the machine
resource "libvirt_domain" "core" {
  name   = "core"
  memory = "1024"
  vcpu   = 2

  cloudinit = "${libvirt_cloudinit_disk.cr_seed.id}"

  network_interface {
    network_id = "${libvirt_network.cr_mgmt_network.id}"
    addresses = [cidrhost("${var.mgmt_network}", "31")]
    network_name = "${libvirt_network.cr_mgmt_network.name}"
  }

  network_interface {
    network_id = "${libvirt_network.cr1_cr_network.id}"
  }

  network_interface {
    network_id = "${libvirt_network.cr2_cr_network.id}"
  }

  disk {
    volume_id = "${libvirt_volume.core.id}"
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
 