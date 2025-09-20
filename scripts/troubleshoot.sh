#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# Set up VAULT environment if available
setup_vault_env 2>/dev/null || true

show_help() {
    cat << EOF
Vault Lab Troubleshooting Tool

Usage: $0 [command]

Commands:
  ttl           - Check token and Secret ID TTLs
  secret-id     - Check Secret ID status and validation
  agent         - Check Vault Agent status and authentication
  kv            - Check KV secrets and versions
  health        - Run comprehensive health check
  monitor       - Show monitoring logs and status
  help          - Show this help

Examples:
  $0 ttl                    # Check all TTLs
  $0 secret-id             # Check Secret ID status
  $0 agent                 # Check agent authentication
  $0 health               # Full health check
EOF
}

check_ttl() {
    echo "=== TTL Status Check ==="
    
    if [[ -z "${VAULT_TOKEN:-}" ]]; then
        echo "❌ VAULT_TOKEN not set. Cannot check token TTL."
        return 1
    fi
    
    echo "1. Current Token TTL:"
    if vault token lookup -format=json 2>/dev/null | jq -r '.data | "TTL: \(.ttl)s | Renewable: \(.renewable) | Uses: \(.num_uses)"'; then
        echo "✅ Token lookup successful"
    else
        echo "❌ Token lookup failed"
    fi
    
    echo -e "\n2. Secret ID Configuration:"
    if vault read -format=json auth/approle/role/dummy-app 2>/dev/null | jq -r '.data | "Secret ID TTL: \(.secret_id_ttl)s | Max Uses: \(.secret_id_num_uses)"'; then
        echo "✅ AppRole configuration accessible"
    else
        echo "❌ AppRole configuration not accessible"
    fi
}

check_secret_id() {
    echo "=== Secret ID Status Check ==="
    
    echo "1. AppRole Role ID:"
    if ROLE_ID=$(vault read -field=role_id auth/approle/role/dummy-app/role-id 2>/dev/null); then
        echo "✅ Role ID: $ROLE_ID"
    else
        echo "❌ Cannot retrieve Role ID"
        return 1
    fi
    
    echo -e "\n2. Secret ID on Agent:"
    if AGENT_SECRET_ID=$(multipass exec vault-agent -- sudo cat /opt/vault-agent/secret-id 2>/dev/null); then
        if [[ "$AGENT_SECRET_ID" =~ ^hvs\.CAESI ]]; then
            echo "⚠️  Secret ID is wrapped: ${AGENT_SECRET_ID:0:20}..."
        else
            echo "✅ Secret ID is unwrapped: ${AGENT_SECRET_ID:0:8}..."
        fi
        
        # Test authentication
        echo -e "\n3. Authentication Test:"
        if vault write auth/approle/login role_id="$ROLE_ID" secret_id="$AGENT_SECRET_ID" >/dev/null 2>&1; then
            echo "✅ Secret ID authentication successful"
        else
            echo "❌ Secret ID authentication failed"
        fi
    else
        echo "❌ Cannot read Secret ID from agent"
    fi
    
    echo -e "\n4. Secret ID Accessors:"
    if vault list auth/approle/role/dummy-app/secret-id 2>/dev/null; then
        echo "✅ Secret ID list accessible"
    else
        echo "❌ Cannot list Secret ID accessors"
    fi
}

check_agent() {
    echo "=== Vault Agent Status Check ==="
    
    echo "1. Agent Service Status:"
    multipass exec vault-agent -- sudo systemctl status vault-agent --no-pager || true
    
    echo -e "\n2. Agent Token File:"
    if multipass exec vault-agent -- sudo ls -la /opt/vault-agent/token 2>/dev/null; then
        echo "✅ Token file exists"
        multipass exec vault-agent -- sudo stat /opt/vault-agent/token
    else
        echo "❌ No token file found"
    fi
    
    echo -e "\n3. Agent Secrets:"
    if multipass exec vault-agent -- sudo ls -la /opt/vault-agent/secrets/ 2>/dev/null; then
        echo "✅ Secrets directory exists"
        if multipass exec vault-agent -- sudo cat /opt/vault-agent/secrets/secret.json 2>/dev/null; then
            echo "✅ Secrets rendered successfully"
        else
            echo "❌ Secrets not rendered"
        fi
    else
        echo "❌ Secrets directory not found"
    fi
    
    echo -e "\n4. Recent Agent Logs:"
    multipass exec vault-agent -- sudo journalctl -u vault-agent --since "5 minutes ago" --no-pager | tail -20
}

check_kv() {
    echo "=== KV Secrets Check ==="
    
    echo "1. KV Engine Status:"
    if vault secrets list | grep -q "kv/"; then
        echo "✅ KV engine enabled"
    else
        echo "❌ KV engine not found"
        return 1
    fi
    
    echo -e "\n2. Available Secrets:"
    if vault kv list kv/ 2>/dev/null; then
        echo "✅ KV secrets accessible"
    else
        echo "❌ Cannot list KV secrets"
    fi
    
    echo -e "\n3. dummy-app Secret:"
    if vault kv get kv/dummy-app 2>/dev/null; then
        echo "✅ dummy-app secret accessible"
    else
        echo "❌ dummy-app secret not accessible"
    fi
    
    echo -e "\n4. Secret Metadata:"
    if vault kv metadata kv/dummy-app -format=json 2>/dev/null | jq -r '.data | "Versions: \(.current_version) | Created: \(.created_time)"'; then
        echo "✅ Secret metadata accessible"
    else
        echo "❌ Secret metadata not accessible"
    fi
}

run_health_check() {
    echo "=== Comprehensive Health Check ==="
    echo "Timestamp: $(date)"
    echo
    
    check_ttl
    echo
    check_secret_id
    echo
    check_agent
    echo
    check_kv
    echo
    
    echo "=== Monitoring Status ==="
    if [[ -f "/tmp/secret-id-monitor.log" ]]; then
        echo "Recent monitoring activity:"
        tail -10 /tmp/secret-id-monitor.log 2>/dev/null || echo "No monitoring logs found"
    else
        echo "No monitoring logs found. Run 'task ansible-monitor' to start monitoring."
    fi
    
    echo -e "\n=== Health Check Complete ==="
}

show_monitor_status() {
    echo "=== Monitoring Status ==="
    
    echo "1. Monitoring Logs:"
    if multipass exec vault-ansible -- cat /tmp/secret-id-monitor.log 2>/dev/null; then
        echo "✅ Monitoring logs found"
    else
        echo "❌ No monitoring logs found"
    fi
    
    echo -e "\n2. Cron Jobs:"
    if multipass exec vault-ansible -- crontab -l 2>/dev/null | grep -i vault; then
        echo "✅ Monitoring cron jobs configured"
    else
        echo "ℹ️  No monitoring cron jobs found"
    fi
    
    echo -e "\n3. Run Manual Monitoring:"
    echo "Execute: task ansible-monitor"
}

# Main execution
case "${1:-help}" in
    "ttl")
        check_ttl
        ;;
    "secret-id")
        check_secret_id
        ;;
    "agent")
        check_agent
        ;;
    "kv")
        check_kv
        ;;
    "health")
        run_health_check
        ;;
    "monitor")
        show_monitor_status
        ;;
    "help"|*)
        show_help
        ;;
esac
