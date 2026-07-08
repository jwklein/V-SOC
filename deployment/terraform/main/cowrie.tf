resource "proxmox_virtual_environment_vm" "cowrie" {
  node_name 	= var.proxmox_node
  description 	= "Managed by Terraform"
  vm_id		= "1501"
  name  = "cowrie"

  clone {
	vm_id	= "1500"
  full  = "false"
 }
  agent {
    enabled   = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "172.30.0.54/24"
        gateway = "172.30.0.254"
      }
    }
    user_account {
      username  = "ubuntu"
      password  = "123456789"
      keys      = [file("~/.ssh/id_ed25519.pub")]
    }
  }

  network_device {
    bridge = var.lan_bridge
  }

  pool_id = "SOC"

  lifecycle {
    ignore_changes = [
      initialization[0].user_account[0].keys
    ]
  }
}
