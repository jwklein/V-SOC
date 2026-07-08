#!/usr/bin/env bash
#
# deploy.sh — automated V-SOC deployment from the IaC controller.
#
# Non-interactive equivalent of documents/manual-deployment.md. Orchestrates
# the Bootstrap and Main stages across Terraform and Ansible.
#
# Requires the vault password in the environment:
#
#   export VAULT_PASS='...'
#   ./deploy.sh
#
# Terraform applies are retried on failure/timeout: apply is idempotent, so a
# re-run reconciles whatever a timeout left incomplete.

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────
TF_MAX_ATTEMPTS="${TF_MAX_ATTEMPTS:-3}"   # terraform apply attempts before giving up
TF_RETRY_DELAY="${TF_RETRY_DELAY:-10}"    # seconds between attempts

# Resolve paths relative to this script so the working directory doesn't matter.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"
TF_NETWORK_INIT="$DEPLOYMENT_DIR/terraform/network-init"
TF_MAIN="$DEPLOYMENT_DIR/terraform/main"
ANSIBLE_DIR="$DEPLOYMENT_DIR/ansible"

log() { echo; echo "[$(date +%H:%M:%S)] $*"; }

# ── Preflight ────────────────────────────────────────────────────────
if [[ -z "${VAULT_PASS:-}" ]]; then
  echo "error: VAULT_PASS is not set. Export it before running:" >&2
  echo "  export VAULT_PASS='...'" >&2
  exit 1
fi

# Feed the vault password to Ansible without writing it to disk or passing it on
# a command line (where it would show up in ps/audit logs): a tiny executable
# password file that echoes the env var at call time. Removed on exit.
VAULT_PASS_SCRIPT="$(mktemp)"
printf '#!/usr/bin/env bash\necho "$VAULT_PASS"\n' > "$VAULT_PASS_SCRIPT"
chmod 700 "$VAULT_PASS_SCRIPT"
export ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_PASS_SCRIPT"
trap 'rm -f "$VAULT_PASS_SCRIPT"' EXIT

# ── Helpers ──────────────────────────────────────────────────────────
terraform_apply_retry() {
  local dir="$1"
  log "terraform init: $dir"
  terraform -chdir="$dir" init -input=false

  local attempt=1
  while (( attempt <= TF_MAX_ATTEMPTS )); do
    log "terraform apply (attempt $attempt/$TF_MAX_ATTEMPTS): $dir"
    if terraform -chdir="$dir" apply -auto-approve -input=false; then
      log "apply succeeded: $dir"
      return 0
    fi
    log "apply failed or timed out; retrying in ${TF_RETRY_DELAY}s..."
    sleep "$TF_RETRY_DELAY"
    attempt=$(( attempt + 1 ))
  done

  echo "error: terraform apply failed after $TF_MAX_ATTEMPTS attempts in $dir" >&2
  return 1
}

play() {   # run an ansible playbook from the ansible dir so ansible.cfg + inventory resolve
  local playbook="$1"
  log "ansible-playbook $playbook"
  ( cd "$ANSIBLE_DIR" && ansible-playbook "playbooks/$playbook" )
}

# ── Stage 1: Bootstrap (network + firewall) ──────────────────────────
log "=== Stage 1: Bootstrap ==="
terraform_apply_retry "$TF_NETWORK_INIT"
play configure_opnsense.yml

# ── Stage 2: Main (lab instances + SIEM) ─────────────────────────────
log "=== Stage 2: Main ==="
terraform_apply_retry "$TF_MAIN"
play make_wazuh_certs_tar.yml
play configure_wazuh_indexer.yml
play configure_wazuh_manager.yml
play configure_wazuh_dashboard.yml
play configure_attackers.yml
play enroll_victim_agents.yml

log "=== V-SOC deployment complete ==="