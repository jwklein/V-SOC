# Manual Deployment

Step-by-step deployment of V-SOC from the IaC controller. This is the manual
equivalent of `deployment/shell/deploy.sh` — use it to deploy stage-by-stage or
to debug a failed step.

For environment prerequisites (golden images, secrets, bridges), see the
[README](../README.md#environment--dependencies).

## Before you begin

- Repo cloned onto the IaC controller.
- Secrets in place: `ansible_vars.yml`, `terraform.tfvars`, SSH keys + config, and the vaults.
- Vault password available (see **Vault password** below — it is not stored in the repo).

All commands are run from `deployment/`.

## Stage 1 — Bootstrap (network + firewall)

Provisions the LAN bridge and clones the OPNsense firewall to a bootstrap WAN IP,
then configures OPNsense with its static primary IP.

```bash
cd terraform/network-init
terraform init          # load providers and dependencies
terraform apply         # create the LAN bridge and firewall VM

cd ../../ansible
ansible-playbook playbooks/configure_opnsense_lan.yml --ask-vault-pass
```

## Stage 2 — Main (lab instances + SIEM)

Provisions the remaining VMs, configures the Wazuh stack, and enrolls agents.

```bash
cd ../terraform/main
terraform init
terraform apply
```
At this point it may be prudent to open metasploitable desktop in proxmox console to verify dchp address is leased
```
cd ../../ansible
ansible-playbook playbooks/make_wazuh_certs_tar.yml
ansible-playbook playbooks/configure_wazuh_indexer.yml
ansible-playbook playbooks/configure_wazuh_manager.yml
ansible-playbook playbooks/configure_wazuh_dashboard.yml
ansible-playbook playbooks/configure_pentest.yml --ask-vault-pass
ansible-playbook playbooks/configure_cowrie.yml
ansible-playbook playbooks/enroll_win2k8_agent.yml --ask-vault-pass
```

Wazuh agent enrollment marks the end of deployment.

## Vault password

`--ask vault pass` signifies playbooks read from vault directories that use a shared password.
Vault encryption & password should be configured manually during IaC controller setup.