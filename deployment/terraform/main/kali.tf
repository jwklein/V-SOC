##############################################################################################################
# This is the terraform page for kali linux. It features an external and internal host placed sqeuentially.
##############################################################################################################

resource "proxmox_virtual_environment_vm" "kali-wan" {
  node_name 	= var.proxmox_node
  description 	= "Managed by Terraform"
  vm_id		= "1201"
  name  = "kali-wan"

  clone {
	vm_id	= "1200"
  full  = "false"
 }
  agent {
    enabled   = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "172.17.0.243/24"
        gateway = "172.17.0.254"
      }
    }
    user_account {
      username  = "kali"
      password  = "123456789"
      keys      = [file("../keyfile.pem")]
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


resource "proxmox_virtual_environment_vm" "kali-lan" {
  node_name   = var.proxmox_node
  description   = "Managed by Terraform"
  vm_id   = "1202"
  name  = "kali-lan"
  depends_on = [proxmox_virtual_environment_vm.kali-wan]

  clone {
  vm_id = "1200"
  full  = "false"
 }
  agent {
    enabled   = true
    
    wait_for_ip {
      ipv4 = false
      ipv6 = false
    }
  }

  initialization {
    ip_config {
      ipv4 {
        address = "172.30.0.195/24"
        gateway = "172.30.0.254"
      }
    }
    user_account {
      username  = "kali"
      password  = "123456789"
      keys      = [file("../keyfile.pem")]
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