resource "proxmox_virtual_environment_vm" "ms3-trusty" {
  node_name 	= var.proxmox_node
  description 	= "Managed by Terraform"
  name     = "victim-trusty"

  vm_id		= "1301"

  clone {
	vm_id	= "1300"
  full  = "false"
 }

  agent {
    enabled   = false
  }

  network_device {
    bridge = var.lan_bridge
  }

  pool_id = "SOC"
}