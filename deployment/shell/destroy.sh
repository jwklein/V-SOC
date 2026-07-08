#!/usr/bin/env bash
#
# fairly simple script to quickly terraform destroy the necessary directories in succession
# 
# the order is terraform destroy terraform/main, terraform destory terraform/network-init.
# 
# the retry mechanism is used to avoid any chances of lingering machines.

# retry parameters
TF_MAX_ATTEMPTS="${TF_MAX_ATTEMPTS:-3}"   # terraform apply attempts before giving up
TF_RETRY_DELAY="${TF_RETRY_DELAY:-10}"    # seconds between attempts

# global target directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"
TF_NETWORK_INIT="$DEPLOYMENT_DIR/terraform/network-init"
TF_MAIN="$DEPLOYMENT_DIR/terraform/main"


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

log "=== Beginning destruction: terraform/main ==="
terraform_apply_retry "$TF_NETWORK_INIT"

log "=== Proceeding destruction: terraform/network-init ==="
terraform_apply_retry "$TF_NETWORK_INIT"

log "=== V-SOC teardown complete ==="