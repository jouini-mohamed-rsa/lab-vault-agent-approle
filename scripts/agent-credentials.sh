#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

setup_agent_credentials() {
    log "Setting up Vault agent AppRole credentials..."
    source generated/vm-ips.env
    
    if [[ ! -f "root-token.txt" ]]; then
        err "Root token not found. Run 'task vault-server' first."
        exit 1
    fi

    log "Delegating credentials provisioning to Ansible playbook (approle)."
    ./scripts/ansible-playbooks.sh approle || true
}

# Main execution
case "${1:-setup}" in
    "setup")
        setup_agent_credentials
        ;;
    *)
        echo "Usage: $0 [setup]"
        exit 1
        ;;
esac
