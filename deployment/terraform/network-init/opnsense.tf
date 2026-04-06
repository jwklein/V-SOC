resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense-swan"
  node_name = var.proxmox_node
  description	= "Managed by Terraform"
  
  vm_id     = 1401

  clone {
    vm_id = 1400
  }

  agent {
    # NOTE: The agent is installed and enabled as part of the cloud-init configuration in the template VM, see cloud-config.tf
    # The working agent is *required* to retrieve the VM IP addresses.
    # If you are using a different cloud-init configuration, or a different clone source
    # that does not have the qemu-guest-agent installed, you may need to disable the `agent` below and remove the `vm_ipv4_address` output.
    # See https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm#qemu-guest-agent for more details.
    enabled = false
  }

  network_device {
    bridge = var.wan_bridge
    mac_address = "BC:24:11:00:DE:87"
  }
  network_device {
    bridge = var.lan_bridge
    mac_address = "BC:24:11:28:D4:21"
  }

  pool_id = "SOC"
}
