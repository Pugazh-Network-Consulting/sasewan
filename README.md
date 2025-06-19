# Topology 3-site

This document describes the steps to create 3-site topology to run the demo on the SD-WAN SASE gateway. 

1. We need to create the VM instance in GCP cloud (n2-standard-8)
2. Enable the nested virutalization in the VM instance created in step-1
3. Now with the terraform create 3-instance of SD-WAN edge and activate in the SD-WAN orchestrator.

## How to create 3-site topology using sasetest 

### Precondition to create 3-site topology in KVM

Before creating topology we need to create KVM hypervisor, We can create KVM hypervisor in below mentioned ways
    1. Create a Hypervisor in Virtual Box/ESXi in private infrastructure
    2. Create a Hypervisor in Cloud infrastructure using GCP 

As of now we have automated the topology creation in GCP environment for 3-site. 

Following is the command to create 3-site topology in KVM hypervisor in Nested Environment. 

    sudo python sasetest.py build kvm -s <kvm hypervisor ip> -u <ssh_username> -k <ssh_key_file> -ev <release_version> -r <repository> -m <management_ip> -tk <token of organization> -ak <access key of the organization>
