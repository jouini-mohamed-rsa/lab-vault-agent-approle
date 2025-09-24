#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# Set up VAULT environment if available
setup_vault_env 2>/dev/null || true

setup_vault_server() {
    log "Setting up Vault server..."
    source generated/vm-ips.env
    
    # Generate config
    mkdir -p generated/config
    sed "s/{{VAULT_IP}}/$VAULT_IP/g" Server/vault.hcl.template > generated/config/vault.hcl
    
    # Transfer files
    multipass transfer generated/certs/vault-cert.pem $VAULT_VM:/tmp/ 2>/dev/null
    multipass transfer generated/certs/vault-key.pem $VAULT_VM:/tmp/ 2>/dev/null
    multipass transfer generated/config/vault.hcl $VAULT_VM:/tmp/ 2>/dev/null
    multipass transfer Server/vault.service $VAULT_VM:/tmp/ 2>/dev/null
    
    # Configure server
    multipass exec $VAULT_VM -- bash -c "
        sudo mv /tmp/vault-cert.pem /opt/vault/certs/
        sudo mv /tmp/vault-key.pem /opt/vault/certs/
        sudo chmod 600 /opt/vault/certs/vault-key.pem
        sudo mv /tmp/vault.hcl /opt/vault/config/
        sudo mv /tmp/vault.service /etc/systemd/system/
        sudo chown -R vault:vault /opt/vault
        sudo systemctl daemon-reload
        sudo systemctl enable vault
        sudo systemctl start vault
    " 2>/dev/null
    
    log "Vault server configured and started"
}

initialize_vault() {
    log "Initializing Vault..."
    source generated/vm-ips.env
    
    wait_for_vault "$VAULT_IP"
    
    # Check if already initialized (with proper environment variables)
    if multipass exec $VAULT_VM -- bash -c "
        export VAULT_ADDR=https://localhost:8200
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
        vault status | grep -q 'Initialized.*true'
    " 2>/dev/null; then
        log "Vault is already initialized"
        return 0
    fi
    
    # Initialize (with proper environment variables)
    INIT_OUTPUT=$(multipass exec $VAULT_VM -- bash -c "
        export VAULT_ADDR=https://localhost:8200
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
        vault operator init -key-shares=1 -key-threshold=1 -format=json
    ")
    
    # Extract credentials
    UNSEAL_KEY=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
    ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
    
    # Save credentials
    echo "$UNSEAL_KEY" > unseal-key.txt
    echo "$ROOT_TOKEN" > root-token.txt
    chmod 600 unseal-key.txt root-token.txt
    
    # Unseal and enable KV (with proper environment variables)
    multipass exec $VAULT_VM -- bash -c "
        export VAULT_ADDR=https://localhost:8200
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
        vault operator unseal $UNSEAL_KEY >/dev/null
    "
    multipass exec $VAULT_VM  -- bash -c "
        echo 'export VAULT_TOKEN=$ROOT_TOKEN' >> ~/.bashrc
        echo 'export VAULT_TOKEN=$ROOT_TOKEN' | sudo tee -a /etc/environment >/dev/null

    " 2>/dev/null

    multipass exec $VAULT_VM -- bash -c "
        export VAULT_ADDR=https://localhost:8200
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
        export VAULT_TOKEN=$ROOT_TOKEN
        vault secrets enable -version=2 kv >/dev/null
    " 2>/dev/null
    
    log "Vault initialized and configured"
}

# Main execution
case "${1:-all}" in
    "setup")
        setup_vault_server
        ;;
    "init")
        initialize_vault
        ;;
    "all")
        setup_vault_server
        initialize_vault
        ;;
    *)
        echo "Usage: $0 [setup|init|all]"
        exit 1
        ;;
esac
