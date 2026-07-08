resource "proxmox_virtual_environment_vm" "ms3-win2k8" {
  node_name   = var.proxmox_node
  description = "Managed by Terraform"
  name        = "victim-trusty"
  vm_id       = "1351"
  clone {
    vm_id = "1350"
    full  = "false"
  }
  agent {
    enabled = false
  }
  network_device {
    bridge      = var.lan_bridge
    mac_address = "BC:24:11:5A:F3:1E" # THIS MAC ADDRESS IS USED TO RESOLVE IP ADDRESS IN ANSIBLE : DO NOT MODIFY WITHOUT UPDATING VARIABLE IN playbooks/resolve_lease.yml
  }
  pool_id = "SOC"
}