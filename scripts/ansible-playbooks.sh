#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

prepare_ansible_vars() {
    log "Preparing Ansible variables..."
    source generated/vm-ips.env
    
    if [[ ! -f "root-token.txt" ]]; then
        err "Root token not found. Run 'task vault-server' first."
        exit 1
    fi
    
    ROOT_TOKEN=$(cat root-token.txt)
    
    # Generate lab-vars.yml with actual values
    sed -e "s/{{VAULT_IP}}/$VAULT_IP/g" \
        -e "s/{{ROOT_TOKEN}}/$ROOT_TOKEN/g" \
        Ansible/lab-vars.yml > generated/inventory/lab-vars.yml
    
    # Transfer to Ansible VM
    multipass transfer generated/inventory/lab-vars.yml $ANSIBLE_VM:/home/ubuntu/ansible/ 2>/dev/null
    
    log "Ansible variables prepared and transferred"
}

run_playbook() {
    local playbook="$1"
    log "Running Ansible playbook: $playbook"
    source generated/vm-ips.env
    
    if [[ ! -f "Ansible/$playbook" ]]; then
        err "Playbook not found: Ansible/$playbook"
        exit 1
    fi
    
    # Transfer all YAML playbooks to ensure includes work
    for yaml_file in Ansible/*.yaml; do
        if [[ -f "$yaml_file" ]]; then
            multipass transfer "$yaml_file" $ANSIBLE_VM:/home/ubuntu/ansible/ 2>/dev/null
        fi
    done
    
    # Run playbook on Ansible VM
    multipass exec $ANSIBLE_VM -- bash -c "
        cd /home/ubuntu/ansible
        source .ansible.env >/dev/null 2>&1
        ansible-playbook $playbook -v
    "
}

# Main execution
case "${1:-help}" in
    "vars")
        prepare_ansible_vars
        ;;
    "run")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 run <playbook.yaml>"
            echo "Available playbooks:"
            ls Ansible/*.yaml 2>/dev/null | xargs -n1 basename
            exit 1
        fi
        prepare_ansible_vars
        run_playbook "$2"
        ;;
    "approle")
        prepare_ansible_vars
        run_playbook "AppRoleConfig.yaml"
        ;;
    "monitor")
        prepare_ansible_vars
        run_playbook "SecretIDMonitor.yaml"
        ;;
    "install-monitor-cron")
        prepare_ansible_vars
        log "Installing SecretIDMonitor cron on Ansible VM (every 20 minutes)..."
        source generated/vm-ips.env
        multipass exec $ANSIBLE_VM -- bash -c '
            set -euo pipefail
            cd /home/ubuntu/ansible
            sudo mkdir -p /var/log/ansible
            sudo chown ubuntu:ubuntu /var/log/ansible
            sudo chmod 755 /var/log/ansible
            # Ensure env file exists for Vault context when playbook runs
            if [[ -f .ansible.env ]]; then
              ENV_SOURCE="source /home/ubuntu/ansible/.ansible.env && "
            else
              ENV_SOURCE=""
            fi
            
            # Create a temporary cron file to avoid shell escaping issues
            TEMP_CRON="/tmp/new_crontab.txt"
            
            # Get existing crontab (if any)
            crontab -l 2>/dev/null > "$TEMP_CRON" || touch "$TEMP_CRON"
            
            # Create the cron job line
            CRON_LINE="*/10 * * * * ${ENV_SOURCE}cd /home/ubuntu/ansible && ansible-playbook SecretIDMonitor.yaml >> /var/log/ansible/secret-id-monitor.log 2>&1"
            
            # Check if this cron job already exists
            if ! grep -q "SecretIDMonitor.yaml" "$TEMP_CRON" 2>/dev/null; then
                echo "$CRON_LINE" >> "$TEMP_CRON"
            else
                # Remove existing SecretIDMonitor lines and add the new one
                grep -v "SecretIDMonitor.yaml" "$TEMP_CRON" > "${TEMP_CRON}.tmp" 2>/dev/null || touch "${TEMP_CRON}.tmp"
                echo "$CRON_LINE" >> "${TEMP_CRON}.tmp"
                mv "${TEMP_CRON}.tmp" "$TEMP_CRON"
            fi
            
            # Install the new crontab
            crontab "$TEMP_CRON"
            
            # Clean up
            rm -f "$TEMP_CRON" "${TEMP_CRON}.tmp"
            
            # Verify installation
            crontab -l | grep -q "SecretIDMonitor.yaml" || exit 1
        '
        ;;
    "all")
        prepare_ansible_vars
        run_playbook "AppRoleConfig.yaml"
        ;;
    *)
        echo "Usage: $0 [vars|run <playbook>|approle|role-id|monitor|install-monitor-cron|all]"
        echo ""
        echo "Available playbooks:"
        ls Ansible/*.yaml 2>/dev/null | xargs -n1 basename || echo "No playbooks found"
        exit 1
        ;;
esac
