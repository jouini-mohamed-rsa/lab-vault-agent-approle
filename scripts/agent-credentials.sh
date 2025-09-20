#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

setup_agent_credentials() {
    log "Setting up Vault agent AppRole credentials..."
    source generated/vm-ips.env
    
    # Check if Ansible credentials exist
    if [[ ! -f "generated/ansible-auth/role-id" ]] || [[ ! -f "generated/ansible-auth/secret-id" ]]; then
        err "Ansible AppRole credentials not found. Run 'task vault-ansible' first."
        exit 1
    fi
    
    # Transfer AppRole credentials to agent VM
    multipass transfer generated/ansible-auth/role-id $AGENT_VM:/tmp/agent-role-id 2>/dev/null
    multipass transfer generated/ansible-auth/secret-id $AGENT_VM:/tmp/agent-secret-id 2>/dev/null
    
    # Setup credentials on agent VM
    multipass exec $AGENT_VM -- bash -c "
        # Create auth directory
        sudo mkdir -p /opt/vault-agent/auth
        
        # Install credentials
        sudo mv /tmp/agent-role-id /opt/vault-agent/role-id
        sudo mv /tmp/agent-secret-id /opt/vault-agent/secret-id
        
        # Set proper permissions
        sudo chmod 600 /opt/vault-agent/role-id /opt/vault-agent/secret-id
        sudo chown vault-agent:vault-agent /opt/vault-agent/role-id /opt/vault-agent/secret-id
        
        echo 'AppRole credentials installed for Vault agent'
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
