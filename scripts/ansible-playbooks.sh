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
    "secret-id")
        prepare_ansible_vars
        run_playbook "SecretIDGen.yaml"
        ;;
    "role-id")
        prepare_ansible_vars
        run_playbook "RoleIDDistribution.yaml"
        ;;
    "monitor")
        prepare_ansible_vars
        run_playbook "SecretIDMonitor.yaml"
        ;;
    "all")
        prepare_ansible_vars
        run_playbook "AppRoleConfig.yaml"
        run_playbook "RoleIDDistribution.yaml"
        run_playbook "SecretIDGen.yaml"
        ;;
    *)
        echo "Usage: $0 [vars|run <playbook>|approle|secret-id|role-id|monitor|all]"
        echo ""
        echo "Available playbooks:"
        ls Ansible/*.yaml 2>/dev/null | xargs -n1 basename || echo "No playbooks found"
        exit 1
        ;;
esac
