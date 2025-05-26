    output "client" {
        value = [ libvirt_domain.client.*.name, libvirt_domain.client.*.network_interface.0.addresses.0]
    }

    output "edge" {
        value = [ libvirt_domain.edge.*.name, libvirt_domain.edge.*.network_interface.0.addresses.0]
    }

    output "core" {
        value = [ libvirt_domain.core.name, libvirt_domain.core.network_interface.0.addresses.0 ]
    }

    output "core1" {
        value = [ libvirt_domain.core1.name, libvirt_domain.core1.network_interface.0.addresses.0 ]
    }
    
    output "core2" {
        value = [ libvirt_domain.core2.name, libvirt_domain.core2.network_interface.0.addresses.0 ]
    }
    