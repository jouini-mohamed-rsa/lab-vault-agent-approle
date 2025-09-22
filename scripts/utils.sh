#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

show_status() {
    echo "=== VM Status ==="
    multipass list
    echo
    
    if [[ -f "generated/vm-ips.env" ]]; then
        source generated/vm-ips.env
        echo "VM Details:"
        echo "  Ansible Control: $ANSIBLE_VM ($ANSIBLE_IP)"
        echo "  Vault Server:    $VAULT_VM ($VAULT_IP)"
        echo "  Vault Agent:     $AGENT_VM ($AGENT_IP)"
        echo
        echo "Vault Access:"
        echo "  UI: https://$VAULT_IP:8200"
        echo "  Root Token: $(cat root-token.txt 2>/dev/null || echo 'Not available')"
        echo
        echo "Ansible AppRole Authentication:"
        echo "  Role ID: $(cat generated/ansible-auth/role-id 2>/dev/null || echo 'Not available')"
        echo "  Secret ID: $(cat generated/ansible-auth/secret-id 2>/dev/null || echo 'Not available')"
    else
        echo "No VM information available. Run 'task init' first."
    fi
}

debug_vms() {
    echo "=== VM Diagnostics ==="
    multipass list
    echo
    
    for vm in vault-ansible vault-server vault-agent; do
        if multipass list | grep -q "^$vm.*Running"; then
            echo "--- $vm ---"
            multipass info $vm
            echo "Cloud-init status:"
            multipass exec $vm -- cloud-init status 2>/dev/null || echo "Cannot check cloud-init status"
            echo
        else
            echo "$vm is not running or not found"
        fi
    done
}

# Main execution
case "${1:-status}" in
    "status")
        show_status
        ;;
    "debug")
        debug_vms
        ;;
    *)
        echo "Usage: $0 [status|debug]"
        exit 1
        ;;
esac
