# Vault AppRole Lab - Production-Ready Architecture

A professional, modular Vault AppRole laboratory environment with automated Secret ID monitoring and management.

## Architecture

```
lab/
├── Taskfile.yml              # Main task orchestration
├── tasks/                    # Modular task definitions
│   ├── init.yml             # Infrastructure tasks
│   ├── server.yml           # Vault server tasks
│   ├── ansible.yml          # Ansible configuration tasks
│   └── agent.yml            # Vault agent tasks
├── scripts/                 # Shell script implementations
│   ├── common.sh            # Shared functions and utilities
│   ├── init.sh              # Infrastructure setup
│   ├── server.sh            # Vault server management
│   ├── ansible.sh           # Ansible configuration
│   ├── agent.sh             # Vault agent setup
│   ├── secrets.sh           # Secret and policy management
│   └── ansible-playbooks.sh # Ansible playbook runner
├── Agent/                   # Vault Agent configuration templates
│   ├── vault-agent.hcl.template    # Agent configuration
│   ├── vault-agent.service.template # Systemd service
│   ├── unwrap-secret-id.sh         # Secret ID unwrapping script
│   └── secret.tmpl                 # Secret template
├── Server/                  # Vault Server configuration templates
│   ├── vault.hcl.template          # Server configuration
│   └── vault-san.conf.template     # Certificate SAN config
├── Ansible/                 # Ansible playbooks and configuration
│   ├── AppRoleConfig.yaml          # AppRole configuration
│   ├── RoleIDDistribution.yaml     # Role ID deployment
│   ├── SecretIDGen.yaml            # Secret ID generation
│   ├── SecretIDMonitor.yaml        # Automated monitoring
│   └── lab-vars.yml                # Centralized variables
├── cloud-init/             # VM initialization scripts
├── apps/                   # Sample applications
│   └── dummy-app.py        # Demo application
└── generated/              # Generated files (runtime)
    ├── certs/              # TLS certificates
    ├── config/             # Generated configurations
    └── ansible-auth/       # AppRole credentials
```

## Key Features

### 🔄 **Automated Secret ID Management**
- **Intelligent Monitoring**: Detects expiring or invalid Secret IDs
- **Automatic Regeneration**: Creates new wrapped Secret IDs when needed
- **Seamless Deployment**: Updates agent credentials without downtime
- **Comprehensive Validation**: Tests Secret ID validity with Vault API

### 🔐 **Enterprise Security**
- **Wrapped Secret IDs**: Secure credential distribution
- **Automatic Unwrapping**: Service-level credential unwrapping
- **TLS Everywhere**: Full certificate chain with proper SANs
- **AppRole Authentication**: Machine-to-machine authentication

### 🏗️ **Production Architecture**
- **Modular Design**: Clean separation of concerns
- **Silent Operation**: Error-only output for clean logs
- **Robust Error Handling**: Fail-fast with recovery mechanisms
- **Scalable Structure**: Easy to extend and maintain

## Prerequisites

- [Taskfile](https://taskfile.dev/installation/)
- [Multipass](https://multipass.run/)
- OpenSSL
- Python 3 (for JSON parsing)

```bash
# macOS
brew install go-task/tap/go-task multipass

# Ubuntu/Debian
snap install multipass
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
```

## Quick Start

### Complete Setup
```bash
# Full lab deployment
task full-setup
```

### Step-by-Step Setup
```bash
# 1. Infrastructure (VMs, certificates, networking)
task infrastructure

# 2. Vault server
task vault-server

# 3. Application secrets and policies
task secrets

# 4. Ansible with AppRole authentication
task vault-ansible

# 5. Vault agent with monitoring
task vault-agent

# Check status
task status
```

## Available Tasks

### Main Workflow
- **`task full-setup`** - Complete lab setup (all components)
- **`task infrastructure`** - Initialize infrastructure (VMs, certs, networking)
- **`task vault-server`** - Setup and initialize Vault server
- **`task secrets`** - Create application secrets and policies
- **`task vault-ansible`** - Setup Ansible with AppRole authentication
- **`task vault-agent`** - Setup Vault agent with auto-unwrapping

### Secret ID Management
- **`task ansible-monitor`** - Run Secret ID monitoring (check and regenerate)
- **`task ansible-secret-id`** - Generate new wrapped Secret ID
- **`task ansible-role-id`** - Deploy Role ID to agent hosts
- **`task ansible-all`** - Run all Ansible playbooks

### Utilities
- **`task status`** - Show lab environment status
- **`task debug-vms`** - Debug VM status and connectivity
- **`task clean`** - Clean up VMs and generated files
- **`task recover-vms`** - Recover VMs in unknown state
- **`task quick-setup`** - Quick infrastructure setup (no cloud-init)
- **`task verify-secrets`** - Test secret access and agent functionality
- **`task setup-vault-env`** - Configure VAULT environment variables on all VMs

### Troubleshooting Tasks
- **`task troubleshoot`** - Run comprehensive health check
- **`task check-ttl`** - Check token and Secret ID TTLs
- **`task check-secret-id`** - Check Secret ID status and validation
- **`task check-agent`** - Check Vault Agent status and authentication
- **`task check-kv`** - Check KV secrets and versions

### SSH Access
- **`task ssh-ansible`** - SSH into Ansible VM
- **`task ssh-server`** - SSH into Vault server VM
- **`task ssh-agent`** - SSH into Vault agent VM

### Granular Control
All tasks support modular execution:
```bash
# Infrastructure components
task init:create-vms
task init:generate-certs
task init:distribute-ca

# Server components
task server:setup
task server:initialize

# Ansible components
task ansible:auth
task ansible:inventory
task ansible:vars

# Agent components
task agent:setup
task agent:configure
task agent:credentials
```

## Secret ID Monitoring System

### Automated Monitoring
The lab includes a production-ready Secret ID monitoring system:

```bash
# Run monitoring manually
task ansible-monitor

# Set up cron job (example)
# */30 * * * * cd /path/to/lab && task ansible-monitor >/dev/null 2>&1
```

### Monitoring Features
- **TTL Monitoring**: Checks remaining Secret ID lifetime
- **Usage Tracking**: Monitors Secret ID usage counts
- **Validity Testing**: Validates credentials with Vault API
- **Automatic Regeneration**: Creates new Secret IDs when needed
- **Seamless Deployment**: Updates agent credentials without service interruption
- **Comprehensive Logging**: Detailed audit trail of all actions

### Configuration
Monitoring behavior is configurable in `Ansible/lab-vars.yml`:
```yaml
# Secret ID Monitoring Configuration
monitor_interval: "30m"                    # How often to run monitoring
secret_id_renewal_threshold: 300           # Renew if TTL < 300 seconds
max_uses_threshold: 0                      # Renew if approaching max uses
```

## Environment Details

After successful deployment:

### VMs Created
- **vault-ansible** (192.168.2.x) - Ansible control node with monitoring
- **vault-server** (192.168.2.x) - Vault server with KV secrets engine
- **vault-agent** (192.168.2.x) - Vault agent with demo app and auto-unwrapping

### Vault Configuration
- **UI**: https://vault-server-ip:8200
- **TLS**: Full certificate chain with proper SANs
- **Authentication**: AppRole method enabled for `dummy-app`
- **Secrets Engine**: KV v2 enabled with demo secrets
- **Policies**: Agent policy for secret access

### Ansible Configuration
- **AppRole credentials**: Automatically configured and monitored
- **Inventory**: Generated with current IPs and agent groups
- **SSH keys**: Distributed for passwordless access
- **Environment**: Ready for Vault operations with helper functions
- **Monitoring**: Secret ID monitoring playbooks ready to run

### Vault Agent Configuration
- **Auto-auth**: AppRole authentication with automatic Secret ID unwrapping
- **Templating**: Secret rendering to JSON files for applications
- **API proxy**: Local proxy for applications on port 8100
- **Caching**: Token and secret caching for performance
- **Monitoring**: Integration with automated Secret ID monitoring

### Sample Application
- **dummy-app**: Python application demonstrating secret consumption
- **Service**: Systemd service with proper dependencies
- **Logging**: Application logs to `/opt/vault-agent/logs/`
- **Configuration**: Reads secrets from rendered JSON files

## Troubleshooting

### Common Issues
```bash
# Check VM status and connectivity
task debug-vms

# Recover failed VMs
task recover-vms

# Clean and restart
task clean
task full-setup

# Test secret access
task verify-secrets
```

### Quick Troubleshooting Commands
```bash
# Comprehensive health check
task troubleshoot

# Check TTLs and expiration
task check-ttl

# Check Secret ID status
task check-secret-id

# Check agent authentication
task check-agent

# Check KV secrets
task check-kv

# Run Secret ID monitoring
task ansible-monitor
```

### TTL and Expiration Monitoring

#### Check Token TTL
```bash
# On any VM with VAULT environment configured
vault token lookup

# Check specific token TTL
vault token lookup -format=json | jq '.data.ttl'

# Check token renewable status
vault token lookup -format=json | jq '.data.renewable'
```

#### Check Secret ID TTL and Usage
```bash
# From Ansible VM (with AppRole token)
vault write auth/approle/role/dummy-app/secret-id/lookup secret_id="YOUR_SECRET_ID"

# Check Secret ID accessor information
vault list auth/approle/role/dummy-app/secret-id

# Get specific Secret ID details
vault write auth/approle/role/dummy-app/secret-id/accessor/lookup secret_id_accessor="ACCESSOR_ID"
```

#### Check KV Secret Versions and Metadata
```bash
# List KV secrets
vault kv list kv/

# Get secret metadata (including version info)
vault kv metadata kv/dummy-app

# Get specific version
vault kv get -version=1 kv/dummy-app

# Check secret history
vault kv metadata kv/dummy-app -format=json | jq '.data.versions'
```

### Agent Token and Secret Expiration Checks

#### Check Agent Authentication Status
```bash
# On Vault Agent VM
multipass exec vault-agent -- bash -c '
    # Check if agent is authenticated
    sudo systemctl status vault-agent
    
    # Check agent token file
    sudo ls -la /opt/vault-agent/token 2>/dev/null || echo "No token file found"
    
    # Check agent logs for authentication errors
    sudo journalctl -u vault-agent --since "10 minutes ago" | grep -i "auth\|error\|token"
'
```

#### Check Secret ID File Status
```bash
# On Vault Agent VM
multipass exec vault-agent -- bash -c '
    # Check Secret ID file
    sudo ls -la /opt/vault-agent/secret-id
    
    # Check if it is a wrapped token
    if sudo cat /opt/vault-agent/secret-id | grep -q "^hvs\.CAESI"; then
        echo "Secret ID is wrapped (needs unwrapping)"
    else
        echo "Secret ID is unwrapped"
    fi
    
    # Check file modification time
    sudo stat /opt/vault-agent/secret-id
'
```

#### Validate Secret ID Against Vault
```bash
# From any VM with VAULT environment
SECRET_ID=$(multipass exec vault-agent -- sudo cat /opt/vault-agent/secret-id)
ROLE_ID=$(vault read -field=role_id auth/approle/role/dummy-app/role-id)

# Test authentication
vault write auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID"
```

#### Check Agent Secret Rendering
```bash
# On Vault Agent VM
multipass exec vault-agent -- bash -c '
    # Check rendered secrets
    sudo ls -la /opt/vault-agent/secrets/
    
    # Check secret content and timestamp
    sudo cat /opt/vault-agent/secrets/secret.json
    sudo stat /opt/vault-agent/secrets/secret.json
    
    # Check agent template logs
    sudo journalctl -u vault-agent | grep -i "template\|render"
'
```

### Automated Monitoring and Alerting

#### Run Comprehensive Secret ID Check
```bash
# Run monitoring playbook
task ansible-monitor

# Check monitoring logs
multipass exec vault-ansible -- cat /tmp/secret-id-monitor.log
```

#### Manual Secret ID Health Check Script
Create a health check script on the Ansible VM:
```bash
multipass exec vault-ansible -- bash -c '
cat > /home/ubuntu/check-secret-health.sh << "EOF"
#!/bin/bash

echo "=== Secret ID Health Check ==="
source /home/ubuntu/ansible/.ansible.env

# Check AppRole configuration
echo "1. AppRole Configuration:"
vault read auth/approle/role/dummy-app

# Check current Secret ID TTL
echo -e "\n2. Current Secret ID TTL:"
SECRET_ID_INFO=$(vault write -format=json auth/approle/role/dummy-app/secret-id metadata={})
echo "$SECRET_ID_INFO" | jq ".data.secret_id_ttl"

# Check Secret ID usage
echo -e "\n3. Secret ID Usage:"
echo "$SECRET_ID_INFO" | jq ".data.secret_id_num_uses"

# List all Secret ID accessors
echo -e "\n4. Active Secret ID Accessors:"
vault list auth/approle/role/dummy-app/secret-id

# Check agent authentication
echo -e "\n5. Test Agent Authentication:"
ROLE_ID=$(vault read -field=role_id auth/approle/role/dummy-app/role-id)
AGENT_SECRET_ID=$(multipass exec vault-agent -- sudo cat /opt/vault-agent/secret-id 2>/dev/null || echo "NOT_FOUND")

if [[ "$AGENT_SECRET_ID" != "NOT_FOUND" ]]; then
    if vault write auth/approle/login role_id="$ROLE_ID" secret_id="$AGENT_SECRET_ID" >/dev/null 2>&1; then
        echo "✅ Agent authentication successful"
    else
        echo "❌ Agent authentication failed"
    fi
else
    echo "❌ Secret ID file not found on agent"
fi

# Check KV secret access
echo -e "\n6. KV Secret Access Test:"
if vault kv get kv/dummy-app >/dev/null 2>&1; then
    echo "✅ KV secrets accessible"
else
    echo "❌ KV secrets not accessible"
fi

echo -e "\n=== Health Check Complete ==="
EOF

chmod +x /home/ubuntu/check-secret-health.sh
'

# Run the health check
multipass exec vault-ansible -- /home/ubuntu/check-secret-health.sh
```

#### Set Up Monitoring Cron Job
```bash
# On Ansible VM - set up automated monitoring
multipass exec vault-ansible -- bash -c '
    # Add cron job for Secret ID monitoring (every 30 minutes)
    (crontab -l 2>/dev/null; echo "*/30 * * * * cd /home/ubuntu/ansible && ansible-playbook SecretIDMonitor.yaml >> /tmp/secret-id-monitor.log 2>&1") | crontab -
    
    # Add daily health check
    (crontab -l 2>/dev/null; echo "0 9 * * * /home/ubuntu/check-secret-health.sh >> /tmp/health-check.log 2>&1") | crontab -
    
    echo "Monitoring cron jobs installed"
    crontab -l
'
```

### Secret ID Issues
```bash
# Check Secret ID status
task ansible-monitor

# Force regeneration
task ansible-secret-id

# Check agent logs
multipass exec vault-agent -- sudo journalctl -u vault-agent -f
```

### Manual Debugging
```bash
# Check individual components
./scripts/utils.sh status

# Test individual scripts
./scripts/init.sh --help
./scripts/server.sh --help
./scripts/agent.sh --help

# Run Ansible playbooks manually
./scripts/ansible-playbooks.sh run SecretIDMonitor.yaml
```

### Logs and Files
- **VM logs**: `multipass exec <vm> -- journalctl -u <service>`
- **Generated files**: `generated/` directory
- **Credentials**: `generated/ansible-auth/`
- **Certificates**: `generated/certs/`
- **Vault Agent logs**: `/opt/vault-agent/logs/` on agent VM
- **Application logs**: `/opt/vault-agent/logs/dummy-app.log`

## Development

### Adding New Components
1. Create script in `scripts/`
2. Create task definition in `tasks/`
3. Include in main `Taskfile.yml`
4. Update documentation

### Modifying Existing Components
- **Scripts**: Edit files in `scripts/`
- **Tasks**: Edit files in `tasks/`
- **Templates**: Edit files in component directories
- **Playbooks**: Edit files in `Ansible/`

### Testing Changes
```bash
# Test individual components
task init:all
task server:all
task ansible:all
task agent:all

# Test monitoring system
task ansible-monitor

# Full integration test
task clean
task full-setup
task verify-secrets
```

### Adding New Monitoring Rules
1. Edit `Ansible/SecretIDMonitor.yaml`
2. Update monitoring logic in the `Determine if Secret ID regeneration is needed` task
3. Adjust thresholds in `Ansible/lab-vars.yml`
4. Test with `task ansible-monitor`

## Security Considerations

### Production Deployment
- **Change default passwords**: Update all default credentials
- **Restrict network access**: Configure firewalls and network policies
- **Enable audit logging**: Configure Vault audit devices
- **Rotate certificates**: Implement certificate rotation procedures
- **Monitor Secret IDs**: Set up automated monitoring with alerting

### Secret Management
- **Wrapped Secret IDs**: Always use wrapped tokens for distribution
- **Short TTLs**: Configure appropriate Secret ID lifetimes
- **Regular rotation**: Implement automated Secret ID rotation
- **Access logging**: Monitor all secret access patterns

## Migration from Previous Version

The old monolithic `setup.sh` has been replaced with this modular architecture:

- **setup.sh** → Multiple focused scripts in `scripts/`
- **Complex Taskfile** → Clean orchestration + modular includes
- **Manual Secret ID management** → Automated monitoring and rotation
- **Template issues** → Resolved through proper separation of concerns
- **No monitoring** → Production-ready monitoring system

All functionality is preserved while significantly improving maintainability, usability, and production readiness.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with `task clean && task full-setup`
5. Update documentation
6. Submit a pull request

## License

This project is provided as-is for educational and development purposes.