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
ansible-playbook playbooks/configure_opnsense.yml --ask-vault-pass
```

## Stage 2 — Main (lab instances + SIEM)

Provisions the remaining VMs, configures the Wazuh stack, and enrolls agents.

```bash
cd ../terraform/main
terraform init
terraform apply

cd ../../ansible
ansible-playbook playbooks/make_wazuh_certs_tar.yml
ansible-playbook playbooks/configure_wazuh_indexer.yml
ansible-playbook playbooks/configure_wazuh_manager.yml
ansible-playbook playbooks/configure_wazuh_dashboard.yml
ansible-playbook playbooks/configure_pentest.yml --ask-vault-pass
ansible-playbook playbooks/enroll_victim_agents.yml
```

Wazuh agent enrollment marks the end of deployment.

## Vault password

Two playbooks — `configure_opnsense.yml` and `configure_attackers.yml` — read
vault-encrypted variables and will prompt for the vault password via
`--ask-vault-pass`.

<!-- TODO: describe the vault password configuration here (how it's set / where it
comes from). Do not commit the actual password. -->