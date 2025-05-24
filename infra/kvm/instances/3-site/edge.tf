resource "libvirt_pool" "core1" {
  name = "core1"
  type = "dir"
  path = "${var.pool_path}/core1"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "core1" {
  name   = "core1"
  pool   = "${libvirt_pool.core1.name}"
  source =  "${var.ubuntu_base_path}"
  format = "qcow2"
}

resource "libvirt_pool" "core2" {
  name = "core2"
  type = "dir"
  path = "${var.pool_path}/core2"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "core2" {
  name   = "core2"
  pool   = "${libvirt_pool.core2.name}"
  source =  "${var.ubuntu_base_path}"
  format = "qcow2"
}

data "template_file" "cr1_network_config" {
  template = file("${path.module}/cr1-network-config.yaml")

  vars = {
    "mgmt_ip" = cidrhost("${var.mgmt_network}", "32") 
    "core1_ip" = cidrhost("111.1.1.0/24", "10")
    "edge1_wan1_ip" = cidrhost("101.1.1.0/24", "1") 
    "edge2_wan1_ip" = cidrhost("101.2.1.0/24", "1")
    "edge3_wan1_ip" = cidrhost("101.3.1.0/24", "1")
    "netmask" = "24"
    "gateway" = cidrhost("111.1.1.0/24", "1")
    "nameserver" = "8.8.8.8"
  }
}

data "template_file" "cr2_network_config" {
  template = file("${path.module}/cr2-network-config.yaml")

  vars = {
    "mgmt_ip" = cidrhost("${var.mgmt_network}", "33") 
    "core2_ip" = cidrhost("112.1.1.0/24", "10")
    "edge1_wan2_ip" = cidrhost("102.1.1.0/24", "1") 
    "edge2_wan2_ip" = cidrhost("102.2.1.0/24", "1")
    "edge3_wan2_ip" = cidrhost("102.3.1.0/24", "1")
    "netmask" = "24"
    "gateway" = cidrhost("112.1.1.0/24", "1")
    "nameserver" = "8.8.8.8"
  }
}


data "template_file" "cr1_user_data" {
  template = file("${path.module}/cr1-user-data.yaml")

  vars = {
    "hostname" = "cr1"
  }
}

data "template_file" "cr2_user_data" {
  template = file("${path.module}/cr2-user-data.yaml")

  vars = {
    "hostname" = "cr2"
  }
}

resource "libvirt_cloudinit_disk" "cr1_seed" {
  name           = "seed.iso"
  user_data      = "${data.template_file.cr1_user_data.rendered}"
  network_config = "${data.template_file.cr1_network_config.rendered}"
  pool           = "${libvirt_pool.core1.name}"
}

resource "libvirt_cloudinit_disk" "cr2_seed" {
  name           = "seed.iso"
  user_data      = "${data.template_file.cr2_user_data.rendered}"
  network_config = "${data.template_file.cr2_network_config.rendered}"
  pool           = "${libvirt_pool.core2.name}"
}

resource "libvirt_network" "cr1_mgmt_network" {
  name  = "cr1-mgmt"
  mode  = "bridge"
  autostart = true
  bridge = "br-mgmt"
}

resource "libvirt_network" "cr2_mgmt_network" {
  name  = "cr2-mgmt"
  mode  = "bridge"
  autostart = true
  bridge = "br-mgmt"
}

resource "libvirt_domain" "core1" {
  name   = "core1"
  memory = "1024"
  vcpu   = 2

  cloudinit = "${libvirt_cloudinit_disk.cr1_seed.id}"

  network_interface {
    network_id = "${libvirt_network.cr1_mgmt_network.id}"
    network_name = "${libvirt_network.cr1_mgmt_network.name}"
    addresses = [cidrhost("${var.mgmt_network}", "32")]
  }

  network_interface {
    network_id = "${libvirt_network.cr1_cr_network.id}"
  }

  network_interface {
    network_id = "${libvirt_network.edge_wan1_network[0].id}"
  }

  network_interface {
    network_id = "${libvirt_network.edge_wan1_network[1].id}"
  }

  # network_interface {
  #   network_id = "${libvirt_network.edge_wan1_network[2].id}"
  # }

  disk {
    volume_id = "${libvirt_volume.core1.id}"
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

resource "libvirt_domain" "core2" {
  name   = "core2"
  memory = "1024"
  vcpu   = 2

  cloudinit = "${libvirt_cloudinit_disk.cr2_seed.id}"

  network_interface {
    network_id = "${libvirt_network.cr2_mgmt_network.id}"
    network_name = "${libvirt_network.cr2_mgmt_network.name}"
    addresses = [cidrhost("${var.mgmt_network}", "33")]
  }

  network_interface {
    network_id = "${libvirt_network.cr2_cr_network.id}"
  }

  network_interface {
    network_id = "${libvirt_network.edge_wan2_network[0].id}"
  }

  network_interface {
    network_id = "${libvirt_network.edge_wan2_network[1].id}"
  }

  # network_interface {
  #   network_id = "${libvirt_network.edge_wan2_network[2].id}"
  # }

  disk {
    volume_id = "${libvirt_volume.core2.id}"
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

resource "libvirt_pool" "edge" {
  count = var.edge_instance_count
  name = "b${count.index + 1}-edge1"
  type = "dir"
  path = "${var.pool_path}/b${count.index + 1}-edge1"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "edge" {
  count = var.edge_instance_count
  name   = "b${count.index + 1}-edge1"
  pool   = "${libvirt_pool.edge["${count.index}"].name}"
  source = "${var.ubuntu_fwedge_path}"
  format = "qcow2"
}

data "template_file" "edge_user_data" {
  count = var.edge_instance_count
  template = file("${path.module}/edge-user-data.yaml")
  vars = {
    "hostname" = "b${count.index + 1}-edge1"
    "token" = "${var.token}"
  }
}

data "template_file" "edge_network_config" {
  count = var.edge_instance_count
  template = file("${path.module}/edge-network-config.yaml")

  vars = {
    "mgmt_ip" = cidrhost("${var.mgmt_network}", "${21 + count.index}") 
    "lan_ip" = cidrhost("10.${count.index + 1}.1.0/24", "1") 
    "wan1_ip" = cidrhost("101.${count.index + 1}.1.0/24", "10")
    "wan2_ip" = cidrhost("102.${count.index + 1}.1.0/24", "10")
    "netmask" = "24"
    "wan1_gateway" = cidrhost("101.${count.index + 1}.1.0/24", "1")
    "wan2_gateway" = cidrhost("102.${count.index + 1}.1.0/24", "1")
    "nameserver" = "8.8.8.8"
  }
}

resource "libvirt_network" "edge_mgmt_network" {
  count = var.edge_instance_count
  name  = "edge${count.index + 1}-mgmt"
  mode  = "bridge"
  autostart = true
  #addresses = [cidrhost("${var.mgmt_network}", "${count.index + 1}")]
  bridge = "br-mgmt"
}

resource "libvirt_network" "edge_lan_network" {
  count = var.edge_instance_count
  name = "lan1-edge${count.index + 1}"
  mode = "bridge"
  bridge = "c1-edge${count.index + 1}"
  autostart = true
}

resource "libvirt_network" "edge_wan1_network" {
  count = var.edge_instance_count
  name = "edge${count.index + 1}-cr1"
  mode = "bridge"
  bridge = "edge${count.index + 1}-cr1"
  autostart = true
}

resource "libvirt_network" "edge_wan2_network" {
  count = var.edge_instance_count
  name = "edge${count.index + 1}-cr2"
  mode = "bridge"
  bridge = "edge${count.index + 1}-cr2"
  autostart = true
}

# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
resource "libvirt_cloudinit_disk" "edge_seed" {
  count          = var.edge_instance_count
  name           = "seed.iso"
  user_data      = "${data.template_file.edge_user_data["${count.index}"].rendered}"
  network_config = "${data.template_file.edge_network_config["${count.index}"].rendered}"
  pool           = "${libvirt_pool.edge["${count.index}"].name}"
}

# Create the machine
resource "libvirt_domain" "edge" {
  count  = var.edge_instance_count
  name   = "b${count.index + 1}-edge1"
  memory = "4096"
  cpu {
    mode = "host-passthrough"
  }
  vcpu   = 4

  cloudinit = "${libvirt_cloudinit_disk.edge_seed["${count.index}"].id}"

  network_interface {
    network_id = "${libvirt_network.edge_mgmt_network["${count.index}"].id}"
    addresses = [cidrhost("${var.mgmt_network}", "${21 + count.index}")]
  }

  network_interface {
    network_id = "${libvirt_network.edge_lan_network["${count.index}"].id}"
  }
    
  network_interface {
    network_id = "${libvirt_network.edge_wan1_network["${count.index}"].id}"
  }

  network_interface {
    network_id = "${libvirt_network.edge_wan2_network["${count.index}"].id}"
  }

  disk {
    volume_id = "${libvirt_volume.edge["${count.index}"].id}"
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
