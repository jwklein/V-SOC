# =============================================================
# Network Resources
# pm2 - Proxmox Node
# vmbr0 - management/external (VLAN-aware)
# vmbr5 - isolated internal
# =============================================================


# -------------------------------------------------------------
# vmbr9 - opnsense-wan, staging hop
# -------------------------------------------------------------
#resource "proxmox_virtual_environment_network_linux_bridge" "vmbr9" {
#  node_name = var.proxmox_node
#  name      = "vmbr9"
#  address   = "172.29.29.0/29"
#  comment   = "stage area"
#}

# -------------------------------------------------------------
# Lan bridge: vmbr10 - isolated internal bridge, no physical port
# -------------------------------------------------------------
resource "proxmox_virtual_environment_network_linux_bridge" lan_bridge {
  node_name = var.proxmox_node
  name      = var.lan_bridge
  address   = "172.30.0.0/24"
  comment   = "Isolated internal lab segment"
}

#############################################################################
# Simple router so that we can control our subnet and query dhcp
#resource "proxmox_virtual_environment_vm" "router" {
#  name      = "router-dnsmasq"
#  node_name = var.proxmox_node
#
#    clone {
#      vm_id = 2000
#    }
#
#    initialization {
#      ip_config {
#        ipv4 {
#          address = "172.17.0.220/24"   # vmbr0 static
#          gateway = "172.17.0.254"
#        }
#      }
#      ip_config {
#        ipv4 {
#          address = "172.29.29.1/29"     # vmbr9 LAN side
#        }
#      }
#      user_account {
#      username  = "ubuntu"
#      password  = "123456789"
#      keys      = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII7Uvnc6OUaaj4gowSqtSCZJNfmoAACwUNSC6hlJEvMw ansible-terraform-lxc"]
#    }
#      user_data_file_id = proxmox_virtual_environment_file.router_cloudinit.id
#    }
#  }

##### Load router_cloudinit
#resource "proxmox_virtual_environment_file" "router_cloudinit" {
#  content_type = "snippets"
#  datastore_id = "local"
#  node_name    = var.proxmox_node
#
#  source_raw {
#    file_name = "router.yaml"
#   data      = templatefile("${path.module}/cloudinit/router.yaml", {
#      opnsense_mac_wan = "BC:24:11:00:DE:87"
#      #wan_mac      = "BC:24:11:00:00:01"
#      #lan_mac      = "BC:24:11:00:00:02"
#    })
#  }
#}