#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

create_demo_secrets() {
    log "Creating demo secrets for dummy application..."
    source generated/vm-ips.env
    
    # Check if Vault is initialized
    if [[ ! -f "root-token.txt" ]]; then
        err "Vault not initialized. Run 'task vault-server' first."
        exit 1
    fi
    
    ROOT_TOKEN=$(cat root-token.txt)
    
    # Create secrets in Vault based on secret.tmpl requirements
    multipass exec $VAULT_VM -- bash -c "
        export VAULT_ADDR=https://localhost:8200
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
        export VAULT_TOKEN=$ROOT_TOKEN
        
        # Create dummy application secrets (matching secret.tmpl structure)
        vault kv put kv/dummy-app \
            db_username=\"demo_user\" \
            db_password=\"demo_password123\" \
            db_host=\"localhost\" \
            db_port=\"5432\" \
            api_key=\"demo_api_key_12345\" \
            api_secret=\"demo_api_secret_67890\"
        
        echo 'Demo secrets created successfully'
    " 2>/dev/null
    
    log "Demo secrets created at kv/dummy-app"
    log "Secrets match the structure defined in Agent/secret.tmpl:"
    log "  - database: username, password, host, port"
    log "  - api: key, secret"
}

create_agent_policy() {
    log "Creating policy for Vault agent..."
    source generated/vm-ips.env
    ROOT_TOKEN=$(cat root-token.txt)
    
    # Create agent policy
    multipass exec $VAULT_VM -- bash -c "
        export VAULT_ADDR=https://localhost:8200
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
        export VAULT_TOKEN=$ROOT_TOKEN
        
        # Create policy for agent to read dummy app secrets
        vault policy write agent-policy - <<EOF
# Allow agent to read dummy app secrets
path \"kv/data/dummy-app\" {
  capabilities = [\"read\"]
}

# Allow agent to read its own token info
path \"auth/token/lookup-self\" {
  capabilities = [\"read\"]
}

# Allow agent to renew its token
path \"auth/token/renew-self\" {
  capabilities = [\"update\"]
}
EOF
        
        echo 'Agent policy created successfully'
    " 2>/dev/null
    
    log "Agent policy created with permissions for kv/dummy-app"
}

verify_secrets() {
    log "Verifying created secrets..."
    source generated/vm-ips.env
    ROOT_TOKEN=$(cat root-token.txt)
    
    # Verify secrets exist and show structure
    multipass exec $VAULT_VM -- bash -c "
        export VAULT_ADDR=https://localhost:8200
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
        export VAULT_TOKEN=$ROOT_TOKEN
        
        echo 'Verifying secrets at kv/dummy-app:'
        vault kv get kv/dummy-app
    " 2>/dev/null
}

# Main execution
case "${1:-secrets}" in
    "create"|"secrets")
        create_demo_secrets
        ;;
    "policy")
        create_agent_policy
        ;;
    "verify")
        verify_secrets
        ;;
    "all")
        create_agent_policy
        create_demo_secrets
        verify_secrets
        ;;
    *)
        echo "Usage: $0 [create|policy|verify|all]"
        exit 1
        ;;
esac
