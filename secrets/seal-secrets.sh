#!/usr/bin/env bash

set -euo pipefail

SEALED_SUFFIX="-sealed-secret.yaml"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR="$SCRIPT_DIR"
OUTPUT_DIR="$SCRIPT_DIR/../infrastructure/secrets"

log_info()  { echo "[INFO]  $1"; }
log_warn()  { echo "[WARN]  $1"; }
log_error() { echo "[ERROR] $1"; }

check_controller() {
  log_info "Checking if sealed-secrets controller is accessible..."
  if ! kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --fetch-cert >/dev/null 2>&1; then
    log_error "Cannot fetch SealedSecrets controller certificate. Is the controller running in 'kube-system'?"
    exit 1
  fi
}

get_namespace() {
  local secret_file="$1"
  if command -v kubectl >/dev/null 2>&1; then
    kubectl create --dry-run=client -f "$secret_file" -o jsonpath='{.metadata.namespace}' 2>/dev/null || true
  else
    grep -E '^[[:space:]]*namespace:' "$secret_file" | head -n1 | awk '{print $2}'
  fi
}

seal_secrets() {
  mkdir -p "$OUTPUT_DIR"

  shopt -s nullglob
  for secret_file in "$INPUT_DIR"/*-secret.yaml; do
    [[ ! -s "$secret_file" ]] && { log_warn "Skipping empty file: $secret_file"; continue; }

    if ! grep -qE '^[[:space:]]*kind:[[:space:]]*Secret' "$secret_file"; then
      log_warn "Skipping $secret_file: not a Kubernetes Secret manifest"
      continue
    fi

    local ns
    ns=$(get_namespace "$secret_file")
    if [[ -z "$ns" ]]; then
      log_warn "Skipping $secret_file: missing metadata.namespace"
      continue
    fi

    local base
    base="$(basename "${secret_file%-secret.yaml}")"
    local sealed_file="$OUTPUT_DIR/${base}${SEALED_SUFFIX}"

    log_info "Sealing $(basename "$secret_file") → $sealed_file [namespace: $ns]..."

    if kubeseal \
        --controller-namespace kube-system \
        --controller-name sealed-secrets-controller \
        --format yaml \
        --scope namespace-wide \
        --namespace "$ns" \
        < "$secret_file" > "$sealed_file"; then
      log_info "Sealed file created: $sealed_file"
    else
      log_error "Failed to seal $secret_file"
    fi
  done
  shopt -u nullglob
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || { log_error "Missing required command: $1"; exit 1; }; }

main() {
  require_cmd kubeseal
  check_controller
  seal_secrets
  log_info "All done."
}


main "$@"
