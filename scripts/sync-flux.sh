#!/usr/bin/env bash

set -euo pipefail

SSH_KEY="$HOME/.ssh/ssh_pulpo"
KNOWN_HOSTS_FILE="/tmp/known_hosts"
PROJECT_ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
FLUX_CONFIG="$PROJECT_ROOT/clusters/kind/flux.yaml"

log_info()    { echo "[INFO]  $1"; }
log_error()   { echo "[ERROR] $1" >&2; exit 1; }

generate_ssh_key() {
  if [[ -f "$SSH_KEY" ]]; then
    log_info "SSH key already exists at '$SSH_KEY'. Skipping generation."
    return
  fi
  log_info "Generating new SSH key '$SSH_KEY'..."
  mkdir -p "$(dirname "$SSH_KEY")"
  ssh-keygen -t rsa -b 4096 -C "flux@pulpo" -f "$SSH_KEY" -N "" >/dev/null
  log_info "SSH key generated. Public key:"
  cat "${SSH_KEY}.pub"
  echo
}

generate_known_hosts() {
  log_info "Caching GitHub public key..."
  mkdir -p "$(dirname "$KNOWN_HOSTS_FILE")" >/dev/null 2>&1
  ssh-keyscan github.com > "$KNOWN_HOSTS_FILE" 2>/dev/null
}

create_flux_secret() {
  log_info "Creating Flux secret..."
  kubectl -n flux-system delete secret flux-system >/dev/null 2>&1 || true
  kubectl -n flux-system create secret generic flux-system \
    --from-file=identity="$SSH_KEY" \
    --from-file=known_hosts="$KNOWN_HOSTS_FILE" \
    >/dev/null 2>&1
}

apply_flux_config() {
  [[ -f "$FLUX_CONFIG" ]] || log_error "Flux config file not found at '$FLUX_CONFIG'."
  log_info "Applying Flux configuration..."
  kubectl apply -f "$FLUX_CONFIG" >/dev/null 2>&1
  log_info "Flux sync started. To observe progress:"
  echo "         kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A"
}

main() {
  generate_ssh_key
  generate_known_hosts
  create_flux_secret
  apply_flux_config
}

main "$@"
