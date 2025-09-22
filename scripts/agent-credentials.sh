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

    ROOT_TOKEN=$(cat root-token.txt)

    # Fetch dummy-app Role ID from Vault server
    ROLE_ID=$(multipass exec $VAULT_VM -- bash -c "\
        export VAULT_ADDR=https://localhost:8200; \
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem; \
        export VAULT_TOKEN=$ROOT_TOKEN; \
        vault read -field=role_id auth/approle/role/dummy-app/role-id 2>/dev/null || echo \"\" ")

    if [[ -z "$ROLE_ID" ]]; then
        log "dummy-app AppRole not found. Attempting to create it via Ansible playbook..."
        # Ensure Ansible variables and playbooks are present on the Ansible VM, then run approle config
        ./scripts/ansible-playbooks.sh approle || true
        # Retry fetching Role ID
        ROLE_ID=$(multipass exec $VAULT_VM -- bash -c "\
            export VAULT_ADDR=https://localhost:8200; \
            export VAULT_CACERT=/opt/vault/certs/ca-cert.pem; \
            export VAULT_TOKEN=$ROOT_TOKEN; \
            vault read -field=role_id auth/approle/role/dummy-app/role-id 2>/dev/null || echo \"\" ")
        if [[ -z "$ROLE_ID" ]]; then
            err "Failed to retrieve dummy-app Role ID after creation attempt. Please run AppRole playbook and retry."
            exit 1
        fi
    fi

    # Ensure jq is available on the Vault server VM
    multipass exec $VAULT_VM -- bash -lc 'command -v jq >/dev/null 2>&1 || (sudo apt-get update -y && sudo apt-get install -y jq -y >/dev/null 2>&1)' 2>/dev/null || true

    # Generate wrapped Secret ID for dummy-app on Vault server (use -force)
    WRAPPED_TOKEN=$(multipass exec $VAULT_VM -- bash -lc "\
        export VAULT_ADDR=https://localhost:8200; \
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem; \
        export VAULT_TOKEN=$ROOT_TOKEN; \
        vault write -force -wrap-ttl=5m -format=json auth/approle/role/dummy-app/secret-id 2>/dev/null | jq -r '.wrap_info.token // empty' ")

    log "Wrapped Token: $WRAPPED_TOKEN"
    log "Root Token: $ROOT_TOKEN"
    log "Role ID: $ROLE_ID"

    if [[ -z "$WRAPPED_TOKEN" || "$WRAPPED_TOKEN" == "null" ]]; then
        err "Failed to generate wrapped Secret ID for dummy-app."
        exit 1
    fi

    # Install credentials directly on the agent VM
    multipass exec $AGENT_VM -- bash -c "
        sudo mkdir -p /opt/vault-agent/auth;
        echo '$ROLE_ID' | sudo tee /opt/vault-agent/role-id >/dev/null;
        echo '$WRAPPED_TOKEN' | sudo tee /opt/vault-agent/secret-id >/dev/null;
        sudo chmod 600 /opt/vault-agent/role-id /opt/vault-agent/secret-id;
        sudo chown vault-agent:vault-agent /opt/vault-agent/role-id /opt/vault-agent/secret-id;
        echo 'AppRole credentials (dummy-app) installed for Vault agent';
    " 2>/dev/null
    
    log "Vault agent AppRole credentials configured"
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
