terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.99"
    }
  }
}

provider "proxmox" {
  endpoint = "https://172.17.0.4:8006/"
  api_token = var.proxmox_api_token
  insecure  = true   
  ssh {
    agent    = false
    username = "root"
    private_key = file(var.proxmox_ssh_keypath)
    
    node {
      name    = "pm1"
      address = "171.17.0.3"
    }
    node {
      name    = "pm2"
      address = "171.17.0.4"
    }
  }
}
