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
- Monitoring cron is installed automatically as part of `task vault-agent` (runs every 20 minutes on the Ansible VM)

### Utilities
- **`task status`** - Show lab environment status
- **`task clean`** - Clean up VMs and generated files


### SSH Access
Use Multipass directly as needed, for example:
```bash
multipass shell vault-ansible
```

### Granular Control
Modular tasks are available for fine-grained control:

**Infrastructure Tasks:**
- `task init:all` - Complete infrastructure setup
- `task init:create-vms` - Create VMs only
- `task init:generate-certs` - Generate certificates only
- `task init:setup-ssh` - Setup SSH connectivity only

**Server Tasks:**
- `task server:all` - Complete server setup
- `task server:setup` - Setup Vault server configuration
- `task server:initialize` - Initialize Vault only

**Ansible Tasks:**
- `task ansible:all` - Complete Ansible setup
- `task ansible:auth` - Setup AppRole authentication only
- `task ansible:inventory` - Create inventory only

**Agent Tasks:**
- `task agent:all` - Complete agent setup
- `task agent:setup` - Setup agent VM only
- `task agent:configure` - Configure agent only
- `task agent:credentials` - Setup credentials only

## Secret ID Monitoring System

### Automated Monitoring
The lab includes a production-ready Secret ID monitoring system:

```bash
# Run monitoring manually on Ansible VM if needed
multipass exec vault-ansible -- bash -c 'cd /home/ubuntu/ansible && ansible-playbook SecretIDMonitor.yaml'
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
- **vault-agent** (192.168.2.x) - Vault agent with Vault Agent

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
The demo Python application and its service are no longer managed in this lab. The lab renders `/opt/vault-agent/secrets/secret.json` for applications to consume.

## Basic Troubleshooting

### Common Issues
```bash
# Check VM status and connectivity
multipass list
multipass info vault-server vault-ansible vault-agent

# Check overall lab status
task status

# Clean and restart if needed
task clean
task full-setup
```

### Quick Troubleshooting Commands
```bash
# Check overall lab status
task status

# Run Secret ID monitoring
./scripts/ansible-playbooks.sh monitor

# Check VM connectivity
multipass list
multipass info vault-server vault-ansible vault-agent
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
./scripts/ansible-playbooks.sh monitor

# Check monitoring logs
multipass exec vault-ansible -- cat /tmp/secret-id-monitor.log
```


#### Set Up Monitoring Cron Job
Installed automatically during `task vault-agent`. To re-install or inspect:
```bash
multipass exec vault-ansible -- crontab -l | sed -n '/SecretIDMonitor.yaml/p'
```

### Secret ID Issues
```bash
# Check Secret ID status
./scripts/ansible-playbooks.sh monitor

# Force regeneration
./scripts/ansible-playbooks.sh secret-id

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
./scripts/ansible-playbooks.sh monitor

# Full integration test
task clean
task full-setup
```

### Adding New Monitoring Rules
1. Edit `Ansible/SecretIDMonitor.yaml`
2. Update monitoring logic in the `Determine if Secret ID regeneration is needed` task
3. Adjust thresholds in `Ansible/lab-vars.yml`
4. Test with `./scripts/ansible-playbooks.sh monitor`

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