#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# Set up VAULT environment if available
setup_vault_env 2>/dev/null || true

setup_agent_vm() {
    log "Setting up Vault agent VM..."
    source generated/vm-ips.env
    
    # Basic preparation only (no application deployment)
    log "Agent VM basic setup completed"
}

configure_vault_agent() {
    log "Configuring Vault agent..."
    source generated/vm-ips.env
    
    # Generate configs
    mkdir -p generated/agent
    sed -e "s/{{VAULT_IP}}/$VAULT_IP/g" \
        -e "s/{{AGENT_IP}}/$AGENT_IP/g" \
        Agent/vault-agent.hcl.template > generated/agent/vault-agent.hcl
    
    sed -e "s/{{AGENT_VM}}/$AGENT_VM/g" \
        -e "s/{{VAULT_IP}}/$VAULT_IP/g" \
        Agent/vault-agent.service.template > generated/agent/vault-agent.service
    
    # Generate unwrap script with proper VAULT_IP
    sed "s/{{VAULT_IP}}/$VAULT_IP/g" \
        Agent/unwrap-secret-id.sh > generated/agent/unwrap-secret-id.sh
    
    # Transfer configs
    multipass transfer generated/agent/vault-agent.hcl $AGENT_VM:/tmp/ 2>/dev/null
    multipass transfer generated/agent/vault-agent.service $AGENT_VM:/tmp/ 2>/dev/null
    multipass transfer generated/agent/unwrap-secret-id.sh $AGENT_VM:/tmp/ 2>/dev/null
    multipass transfer Agent/secret.tmpl $AGENT_VM:/tmp/ 2>/dev/null
    
    # Configure agent
    multipass exec $AGENT_VM -- bash -c "
        # Create directories with proper permissions
        sudo mkdir -p /opt/vault-agent/{config,templates,secrets,bin,logs}
        
        # Install configuration files
        sudo mv /tmp/vault-agent.hcl /opt/vault-agent/config/
        sudo mv /tmp/secret.tmpl /opt/vault-agent/templates/
        sudo mv /tmp/unwrap-secret-id.sh /opt/vault-agent/bin/
        
        # Install service file
        sudo mv /tmp/vault-agent.service /etc/systemd/system/
        
        # Set proper permissions and ownership
        sudo chmod +x /opt/vault-agent/bin/unwrap-secret-id.sh
        sudo chmod 755 /opt/vault-agent
        sudo chmod 755 /opt/vault-agent/{config,templates,secrets,bin,logs}
        sudo chmod 644 /opt/vault-agent/config/vault-agent.hcl
        sudo chmod 644 /opt/vault-agent/templates/secret.tmpl
        
        # Set ownership recursively
        sudo chown -R vault-agent:vault-agent /opt/vault-agent
        
        # Ensure vault-agent user can write to the directory
        sudo chmod 775 /opt/vault-agent
        
        # Enable service (do not start yet; credentials may not be present)
        sudo systemctl daemon-reload
        sudo systemctl enable vault-agent
    " 2>/dev/null
    
    log "Vault agent configured"
}

# Start or restart vault-agent service once credentials are present
start_vault_agent_service() {
    log "Starting vault-agent service..."
    source generated/vm-ips.env
    multipass exec $AGENT_VM -- bash -c '
        set -e
        sudo systemctl restart vault-agent || sudo systemctl start vault-agent
        sudo systemctl is-active --quiet vault-agent && echo "vault-agent is active"
    ' 2>/dev/null
}

# Install monitoring cron on Ansible VM (every 20 minutes)
install_monitoring_cron() {
    log "Installing SecretIDMonitor cron on Ansible VM (every 20 minutes)..."
    # Reuse playbook helper to ensure variables and playbooks are present
    ./scripts/ansible-playbooks.sh vars
    ./scripts/ansible-playbooks.sh install-monitor-cron
    log "SecretIDMonitor cron installed on Ansible VM"
}

# Main execution
case "${1:-all}" in
    "setup")
        setup_agent_vm
        ;;
    "configure")
        configure_vault_agent
        ;;
    "credentials")
        ./scripts/agent-credentials.sh setup
        ;;
    "all")
        setup_agent_vm
        configure_vault_agent
        ./scripts/agent-credentials.sh setup
        start_vault_agent_service
        install_monitoring_cron
        ;;
    *)
        echo "Usage: $0 [setup|configure|credentials|all]"
        exit 1
        ;;
esac
