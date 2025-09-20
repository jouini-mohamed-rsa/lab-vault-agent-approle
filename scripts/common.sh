#!/bin/bash

# Common functions and variables

log() { 
    echo "[lab] $*" 
}

err() { 
    echo "[lab][ERROR] $*" >&2 
}

setup_vault_env() {
    # Set up VAULT environment variables for all operations
    if [[ -f "generated/vm-ips.env" ]]; then
        source generated/vm-ips.env
        export VAULT_ADDR="https://$VAULT_IP:8200"
        export VAULT_CACERT="$(pwd)/generated/certs/ca-cert.pem"
        
        # Set token if available
        if [[ -f "root-token.txt" ]]; then
            export VAULT_TOKEN="$(cat root-token.txt)"
        fi
        
        log "VAULT environment configured: $VAULT_ADDR"
    else
        err "VM configuration not found. Run infrastructure setup first."
        return 1
    fi
}

setup_vault_env_on_vm() {
    local vm_name="$1"
    local vault_ip="${2:-$VAULT_IP}"
    
    multipass exec "$vm_name" -- bash -c "
        # Create global vault environment file
        sudo mkdir -p /etc/environment.d
        sudo tee /etc/environment.d/vault.conf > /dev/null << 'EOF'
VAULT_ADDR=https://$vault_ip:8200
VAULT_CACERT=/opt/vault/certs/ca-cert.pem
EOF
        
        # Add to bashrc for interactive sessions
        if ! grep -q 'VAULT_ADDR' /home/ubuntu/.bashrc 2>/dev/null; then
            cat >> /home/ubuntu/.bashrc << 'EOF'

# Vault environment variables
export VAULT_ADDR=https://$vault_ip:8200
export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
EOF
        fi
        
        # Reload systemd environment
        sudo systemctl daemon-reload 2>/dev/null || true
    "
}

cleanup_vms() {
    log "Cleaning up VMs..."
    for vm in vault-ansible vault-server vault-agent; do
        if multipass list | grep -q "^$vm"; then
            multipass stop $vm 2>/dev/null || true
            multipass delete $vm 2>/dev/null || true
        fi
    done
    multipass purge 2>/dev/null || true
    rm -rf generated/ *.txt *.log /tmp/*-cloud-init.yaml /tmp/ansible-* 2>/dev/null || true
}

check_prerequisites() {
    if ! command -v multipass >/dev/null; then
        err "Multipass is not installed"
        exit 1
    fi
    
    if ! command -v openssl >/dev/null; then
        err "OpenSSL is not installed"
        exit 1
    fi
}

wait_for_vault() {
    local vault_ip="$1"
    log "Waiting for Vault service to respond..."
    
    # Source environment to get VAULT_VM variable
    source generated/vm-ips.env 2>/dev/null || {
        VAULT_VM="vault-server"  # fallback
    }
    
    for i in {1..10}; do  # Quick check - just need Vault to respond
        if multipass exec $VAULT_VM -- curl -k -s https://localhost:8200/v1/sys/health 2>/dev/null | grep -q '"version"'; then
            log "Vault service is responding"
            return 0
        fi
        
        log "Waiting for Vault service... (attempt $i/10)"
        sleep 3
    done
    
    err "Vault service failed to respond"
    return 1
}
