
resource "proxmox_virtual_environment_vm" "wazuh-indx-mngr" {
  node_name 	= var.proxmox_node
  description 	= "Managed by Terraform"
  vm_id		= "1101"
  name  = "wazuh-indx-mngr"

  clone {
	vm_id	= "1100"
  full  = "true"
 }
  agent {
    enabled   = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "172.30.0.10/24"
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

resource "proxmox_virtual_environment_vm" "wazuh-dashboard" {
  node_name 	= var.proxmox_node
  description 	= "Managed by Terraform"
  vm_id		= "1111"
  name    = "wazuh-dashboard"

  clone {
	vm_id	= "1110"
  full  = "true"
 }


  agent {
    enabled   = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "172.17.0.238/24"
        gateway = "172.17.0.254"
      }
    }
    user_account {
      username  = "ubuntu"
      password  = "123456789"
      keys      = [file("~/.ssh/id_ed25519.pub")]
    }
  }

  network_device {
    bridge = var.wan_bridge
  }

  pool_id = "SOC"

  lifecycle {
    ignore_changes = [
      initialization[0].user_account[0].keys
    ]
  }
}