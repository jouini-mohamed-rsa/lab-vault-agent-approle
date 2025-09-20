#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# VM configuration
ANSIBLE_VM="vault-ansible"
VAULT_VM="vault-server"
AGENT_VM="vault-agent"
VM_CPUS=2
VM_MEMORY="2G"
VM_DISK="10G"
UBUNTU_VERSION="22.04"

create_vms() {
    log "Creating Multipass VMs..."
    
    # Verify cloud-init files exist
    for config in ansible-control vault-server vault-agent; do
        if [[ ! -f "cloud-init/${config}.yaml" ]]; then
            err "Cloud-init config not found: cloud-init/${config}.yaml"
            exit 1
        fi
    done
    
    # Create VMs
    for vm_config in "$ANSIBLE_VM:ansible-control" "$VAULT_VM:vault-server" "$AGENT_VM:vault-agent"; do
        vm_name="${vm_config%:*}"
        config_name="${vm_config#*:}"
        
        if multipass list | grep -q "^$vm_name"; then
            log "VM $vm_name already exists, skipping"
            continue
        fi
        
        log "Creating $vm_name..."
        multipass launch $UBUNTU_VERSION \
            --name $vm_name \
            --cpus $VM_CPUS \
            --memory $VM_MEMORY \
            --disk $VM_DISK \
            --cloud-init cloud-init/${config_name}.yaml \
            --timeout 600 || {
            log "Retrying $vm_name with basic launch..."
            multipass launch $UBUNTU_VERSION --name $vm_name --timeout 300
        }
    done
    
    # Wait for cloud-init
    log "Waiting for cloud-init completion..."
    sleep 30
    
    for vm in $ANSIBLE_VM $VAULT_VM $AGENT_VM; do
        log "Checking $vm cloud-init status..."
        
        # Check cloud-init status without --wait to avoid hanging
        local status=$(multipass exec $vm -- cloud-init status 2>/dev/null | awk '{print $2}' || echo "unknown")
        
        if [[ "$status" == "done" ]]; then
            log "$vm cloud-init completed successfully"
        elif [[ "$status" == "running" ]]; then
            log "$vm cloud-init still running, waiting..."
            # Wait a bit more for running cloud-init
            for i in {1..12}; do  # Wait up to 1 minute more
                sleep 5
                status=$(multipass exec $vm -- cloud-init status 2>/dev/null | awk '{print $2}' || echo "unknown")
                if [[ "$status" == "done" ]]; then
                    log "$vm cloud-init completed"
                    break
                fi
            done
        else
            log "$vm cloud-init status: $status - checking VM responsiveness..."
            if multipass exec $vm -- echo "test" >/dev/null 2>&1; then
                log "$vm is responsive, continuing..."
            else
                err "$vm is not responsive"
                exit 1
            fi
        fi
    done
}

get_vm_ips() {
    log "Getting VM IP addresses..."
    
    ANSIBLE_IP=$(multipass info $ANSIBLE_VM | grep IPv4 | awk '{print $2}')
    VAULT_IP=$(multipass info $VAULT_VM | grep IPv4 | awk '{print $2}')
    AGENT_IP=$(multipass info $AGENT_VM | grep IPv4 | awk '{print $2}')
    
    log "VM IPs: Ansible=$ANSIBLE_IP, Vault=$VAULT_IP, Agent=$AGENT_IP"
    
    # Save IPs
    mkdir -p generated
    cat > generated/vm-ips.env <<EOF
ANSIBLE_VM=$ANSIBLE_VM
VAULT_VM=$VAULT_VM
AGENT_VM=$AGENT_VM
ANSIBLE_IP=$ANSIBLE_IP
VAULT_IP=$VAULT_IP
AGENT_IP=$AGENT_IP
EOF
}

generate_certs() {
    log "Generating TLS certificates..."
    source generated/vm-ips.env
    mkdir -p generated/certs
    
    # CA certificate
    openssl genrsa -out generated/certs/ca-key.pem 2048 2>/dev/null
    openssl req -new -x509 -days 365 -key generated/certs/ca-key.pem \
        -out generated/certs/ca-cert.pem \
        -subj "/C=US/ST=CA/L=Lab/O=Vault Lab/CN=Vault Lab CA" 2>/dev/null
    
    # Vault server certificate
    openssl genrsa -out generated/certs/vault-key.pem 2048 2>/dev/null
    openssl req -new -key generated/certs/vault-key.pem \
        -out generated/certs/vault.csr \
        -subj "/C=US/ST=CA/L=Lab/O=Vault Lab/CN=vault-server" 2>/dev/null
    
    # Generate SAN config
    sed -e "s/{{VAULT_VM}}/$VAULT_VM/g" \
        -e "s/{{VAULT_IP}}/$VAULT_IP/g" \
        Server/vault-san.conf.template > generated/certs/vault-san.conf
    
    # Sign certificate
    openssl x509 -req -days 365 \
        -in generated/certs/vault.csr \
        -CA generated/certs/ca-cert.pem \
        -CAkey generated/certs/ca-key.pem \
        -CAcreateserial \
        -out generated/certs/vault-cert.pem \
        -extensions v3_req \
        -extfile generated/certs/vault-san.conf 2>/dev/null
    
    chmod 644 generated/certs/*.pem
    chmod 600 generated/certs/ca-key.pem generated/certs/vault-key.pem
    
    log "TLS certificates generated"
}

distribute_ca_certs() {
    log "Distributing CA certificates..."
    source generated/vm-ips.env
    
    for vm in $ANSIBLE_VM $VAULT_VM $AGENT_VM; do
        multipass transfer generated/certs/ca-cert.pem $vm:/tmp/ca-cert.pem
        multipass exec $vm -- bash -c "
            sudo cp /tmp/ca-cert.pem /usr/local/share/ca-certificates/vault-lab-ca.crt
            sudo update-ca-certificates >/dev/null 2>&1
            sudo mkdir -p /opt/vault/certs
            sudo cp /tmp/ca-cert.pem /opt/vault/certs/ca-cert.pem
            echo 'export VAULT_ADDR=https://$VAULT_IP:8200' | sudo tee -a /etc/environment >/dev/null
            echo 'export VAULT_CACERT=/opt/vault/certs/ca-cert.pem' | sudo tee -a /etc/environment >/dev/null
            echo 'export VAULT_ADDR=https://$VAULT_IP:8200' >> ~/.bashrc
            echo 'export VAULT_CACERT=/opt/vault/certs/ca-cert.pem' >> ~/.bashrc
            rm /tmp/ca-cert.pem
        " 2>/dev/null
    done
    
    log "CA certificates distributed"
}

setup_ssh() {
    log "Setting up SSH connectivity..."
    source generated/vm-ips.env
    
    # Wait for SSH key generation
    for i in {1..30}; do
        if multipass exec $ANSIBLE_VM -- test -f /home/ubuntu/.ssh/id_rsa.pub 2>/dev/null; then
            break
        fi
        sleep 2
    done
    
    ANSIBLE_PUBKEY=$(multipass exec $ANSIBLE_VM -- cat /home/ubuntu/.ssh/id_rsa.pub)
    
    # Distribute to other VMs
    for vm in $VAULT_VM $AGENT_VM; do
        multipass exec $vm -- bash -c "
            echo '$ANSIBLE_PUBKEY' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        " 2>/dev/null
    done
    
    log "SSH connectivity configured"
}

setup_vault_env_all_vms() {
    log "Setting up VAULT environment variables on all VMs..."
    
    # Source VM IPs
    source generated/vm-ips.env
    
    # Set up VAULT environment on each VM
    for vm in "$ANSIBLE_VM" "$VAULT_VM" "$AGENT_VM"; do
        log "Configuring VAULT environment on $vm..."
        setup_vault_env_on_vm "$vm" "$VAULT_IP"
    done
    
    log "VAULT environment setup completed on all VMs"
}

# Main execution
case "${1:-all}" in
    "vms")
        create_vms
        ;;
    "ips")
        get_vm_ips
        ;;
    "certs")
        generate_certs
        ;;
    "ca")
        distribute_ca_certs
        ;;
    "ssh")
        setup_ssh
        ;;
    "vault-env")
        setup_vault_env_all_vms
        ;;
    "all")
        create_vms
        get_vm_ips
        generate_certs
        distribute_ca_certs
        setup_ssh
        setup_vault_env_all_vms
        log "Infrastructure initialization completed"
        ;;
    *)
        echo "Usage: $0 [vms|ips|certs|ca|ssh|vault-env|all]"
        exit 1
        ;;
esac
