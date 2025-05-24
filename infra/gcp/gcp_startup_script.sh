#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Write a status file to show the execution status
startup_script_status_file="/tmp/gcp_startup_script_status"
echo "running" > $startup_script_status_file

# Check if nested virtualization is enabled
echo "INFO: Checking if nested virtualization is enabled ..."
nested_virt_sys_file="/sys/module/kvm_intel/parameters/nested"
nested_virt="$(cat ${nested_virt_sys_file})"
if [[ ! -f $nested_virt_sys_file || "$nested_virt" != "Y" ]] ; then
    echo "ERROR: GCP instance does not have nested virtualization enabled"
    echo "       Exit with failure"
    echo "fail" > $startup_script_status_file
    exit 1
fi

# Install required packages
echo "INFO: Installing required packages ..."
apt update
apt -y install bridge-utils \
    ipxe-qemu \
    ipxe-qemu-256k-compat-efi-roms \
    libvirglrenderer1 \
    libvirt-clients \
    libvirt-daemon \
    libvirt-daemon-driver-qemu \
    libvirt-daemon-driver-storage-rbd \
    libvirt-daemon-system \
    libvirt-daemon-system-systemd \
    libvirt0 \
    virtinst \
    python3-libvirt \
    qemu \
    qemu-block-extra \
    qemu-kvm \
    qemu-system-common \
    qemu-system-data \
    qemu-system-gui \
    qemu-system-x86 \
    qemu-utils \
    linux-modules-extra-$(uname -r)

# Configure user permissions to libvirt/kvm
echo "INFO: Configuring user permissions to kvm/libvirt ..."
usermod -aG libvirt ubuntu
usermod -aG kvm ubuntu

# Fix libvirt permissions issue with terraform. For reference:
# https://github.com/dmacvicar/terraform-provider-libvirt/commit/22f096d9
echo "INFO: Fixing libvirt permissions issue with terraform and restarting libvirtd service ..."
qemu_config_file="/etc/libvirt/qemu.conf"
sed -i -e 's/^#security_driver = .*/security_driver = "none"/g' $qemu_config_file
systemctl restart libvirtd.service

# Configure netplan to add a bridge for management network,
# and attach the second network interface into it
echo "INFO: Configuring and re-applying netplan ..."
netplan_config_file="/etc/netplan/50-cloud-init.yaml"
netplan_config_file_backup="${netplan_config_file}.bak"
wan_iface="$(ip route list default | grep -Eo "dev [a-z0-9]+" | cut -d " " -f2)"
mgmt_iface="$(ip route | grep -Eo "dev [a-z0-9]+" | cut -d " " -f2 | grep -Ev "virbr[0-9]+|${wan_iface}" | uniq)"
mgmt_mac="$(cat /sys/class/net/${mgmt_iface}/address)"

# Set hardcore /24 since this is the netmask used to create such subnetwork in GCP
mgmt_ip="$(ip a sh dev $mgmt_iface | grep -Eo "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | cut -d " " -f 2)/24"

mgmt_br_iface="br-mgmt"
if [ ! -f $netplan_config_file_backup ] ; then
    cp $netplan_config_file $netplan_config_file_backup
fi

sed -i -e '/version: 2/d' $netplan_config_file
cat << EOF >> $netplan_config_file
        MGMT_IFACE:
            dhcp4: false
            set-name: MGMT_IFACE
            match:
                macaddress: MGMT_MAC
    bridges:
        MGMT_BR_IFACE:
            interfaces: [MGMT_IFACE]
            addresses:
                - MGMT_IP
            dhcp4: false
            parameters:
                stp: true
                forward-delay: 4
    version: 2
EOF

sed -i -e "s|MGMT_IFACE|$mgmt_iface|g" \
    -e "s|MGMT_MAC|$mgmt_mac|g" \
    -e "s|MGMT_BR_IFACE|$mgmt_br_iface|g" \
    -e "s|MGMT_IP|$mgmt_ip|g" $netplan_config_file

netplan apply -debug

# Configure iptables to provide Internet connectivity to the KVM environment
echo "INFO: Configuring iptables to provide Internet connectivity to the KVM environment ..."
iptables -t nat -A POSTROUTING -o $wan_iface -j MASQUERADE
iptables -t nat -A POSTROUTING -o $mgmt_br_iface -j MASQUERADE
apt -y install iptables-persistent

# Last check
kvm-ok

echo "ok" > $startup_script_status_file
