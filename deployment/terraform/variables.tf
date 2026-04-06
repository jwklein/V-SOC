variable "proxmox_api_token" {
  description = "Proxmox API token in format kleinjw@miamildap!tokenid=secret"
  sensitive   = true
}
variable "proxmox_ssh_keypath" {
  description = "Root SSH key path for pm2"
  sensitive   = true
}
variable "proxmox_node" {
  description = "name of our working node"
}
variable "wan_bridge" {
  description = "the name of the wan bridge"
}
variable "lan_bridge" {
  description = "the name of the lan bridge"
}