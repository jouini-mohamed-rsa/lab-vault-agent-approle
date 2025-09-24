#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# Set up VAULT environment if available
setup_vault_env 2>/dev/null || true

prepare_ansible_auth() {
    log "Preparing Ansible authentication..."
    source generated/vm-ips.env
    ROOT_TOKEN=$(cat root-token.txt)
    
    # Enable AppRole and create policy
    multipass exec $VAULT_VM -- bash -c "
        export VAULT_TOKEN=$ROOT_TOKEN
        export VAULT_ADDR=https://localhost:8200
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
        
        if ! vault auth list | grep -q 'approle/'; then
            vault auth enable approle >/dev/null
        fi
    " 2>/dev/null
    
    # Transfer and load policy
    multipass transfer Ansible/ansible-policy.hcl $VAULT_VM:/tmp/ 2>/dev/null
    multipass exec $VAULT_VM -- bash -c "
        export VAULT_TOKEN=$ROOT_TOKEN
        export VAULT_ADDR=https://localhost:8200
        export VAULT_CACERT=/opt/vault/certs/ca-cert.pem
        
        vault policy write ansible-policy /tmp/ansible-policy.hcl >/dev/null
        rm /tmp/ansible-policy.hcl
        
        # Create AppRole
        vault write auth/approle/role/ansible-role \
            token_policies=\"ansible-policy\" \
            token_ttl=1h \
            token_max_ttl=4h \
            secret_id_ttl=0 \
            secret_id_num_uses=0 >/dev/null
        
        # Get credentials
        ROLE_ID=\$(vault read -field=role_id auth/approle/role/ansible-role/role-id)
        SECRET_ID=\$(vault write -force -field=secret_id auth/approle/role/ansible-role/secret-id)
        
        echo \$ROLE_ID > /tmp/ansible-role-id
        echo \$SECRET_ID > /tmp/ansible-secret-id
    " 2>/dev/null
    
    # Transfer credentials
    multipass transfer $VAULT_VM:/tmp/ansible-role-id /tmp/ 2>/dev/null
    multipass transfer $VAULT_VM:/tmp/ansible-secret-id /tmp/ 2>/dev/null
    multipass transfer /tmp/ansible-role-id $ANSIBLE_VM:/tmp/ 2>/dev/null
    multipass transfer /tmp/ansible-secret-id $ANSIBLE_VM:/tmp/ 2>/dev/null
    
    # Setup on Ansible VM
    multipass exec $ANSIBLE_VM -- bash -c "
        mkdir -p /home/ubuntu/ansible/credentials
        mv /tmp/ansible-role-id /home/ubuntu/ansible/credentials/role-id
        mv /tmp/ansible-secret-id /home/ubuntu/ansible/credentials/secret-id
        chmod 600 /home/ubuntu/ansible/credentials/*
        
        cat > /home/ubuntu/ansible/credentials/approle.env <<EOF
export VAULT_ROLE_ID=\\\$(cat /home/ubuntu/ansible/credentials/role-id)
export VAULT_SECRET_ID=\\\$(cat /home/ubuntu/ansible/credentials/secret-id)
export VAULT_AUTH_METHOD=approle
EOF
    " 2>/dev/null
    
    # Cleanup and save locally
    rm -f /tmp/ansible-*
    multipass exec $VAULT_VM -- rm -f /tmp/ansible-* 2>/dev/null
    
    mkdir -p generated/ansible-auth
    multipass exec $ANSIBLE_VM -- cat /home/ubuntu/ansible/credentials/role-id > generated/ansible-auth/role-id 2>/dev/null
    multipass exec $ANSIBLE_VM -- cat /home/ubuntu/ansible/credentials/secret-id > generated/ansible-auth/secret-id 2>/dev/null
    chmod 600 generated/ansible-auth/*
    
    log "Ansible AppRole authentication configured"
}

create_ansible_inventory() {
    log "Creating Ansible inventory..."
    source generated/vm-ips.env
    
    mkdir -p generated/inventory
    
    # Generate files
    sed -e "s/{{VAULT_IP}}/$VAULT_IP/g" \
        -e "s/{{AGENT_IP}}/$AGENT_IP/g" \
        -e "s/{{AGENT_VM}}/$AGENT_VM/g" \
        Ansible/hosts.template > generated/inventory/hosts
    
    sed "s/{{VAULT_IP}}/$VAULT_IP/g" Ansible/group_vars > generated/inventory/group_vars
    sed "s/{{VAULT_IP}}/$VAULT_IP/g" Ansible/.ansible.env.template > generated/inventory/.ansible.env.debug
    sed "s/{{VAULT_IP}}/$VAULT_IP/g" Ansible/.ansible.env.simple > generated/inventory/.ansible.env
    cp Ansible/ansible.cfg generated/inventory/
    
    # Transfer to Ansible VM
    multipass exec $ANSIBLE_VM -- mkdir -p /home/ubuntu/ansible 2>/dev/null
    for file in hosts group_vars .ansible.env .ansible.env.debug ansible.cfg; do
        multipass transfer generated/inventory/$file $ANSIBLE_VM:/home/ubuntu/ansible/ 2>/dev/null
    done
    
    # Add auto-source to .bashrc for convenience
    multipass exec $ANSIBLE_VM -- bash -c "
        if ! grep -q 'source /home/ubuntu/ansible/.ansible.env' ~/.bashrc; then
            echo '' >> ~/.bashrc
            echo '# Auto-load Vault environment for Ansible' >> ~/.bashrc
            echo 'if [[ -f /home/ubuntu/ansible/.ansible.env ]]; then' >> ~/.bashrc
            echo '    source /home/ubuntu/ansible/.ansible.env' >> ~/.bashrc
            echo 'fi' >> ~/.bashrc
        fi
    " 2>/dev/null
    
    log "Ansible inventory created and transferred"
    log "Vault environment will auto-load when SSH into Ansible VM"
}

# Main execution
case "${1:-all}" in
    "auth")
        prepare_ansible_auth
        ;;
    "inventory")
        create_ansible_inventory
        ;;
    "all")
        prepare_ansible_auth
        create_ansible_inventory
        ;;
    *)
        echo "Usage: $0 [auth|inventory|all]"
        exit 1
        ;;
esac
