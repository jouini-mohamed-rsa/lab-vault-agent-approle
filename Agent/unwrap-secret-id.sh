#!/bin/bash

SECRET_ID_FILE="/opt/vault-agent/secret-id"
VAULT_ADDR="${VAULT_ADDR:-https://{{VAULT_IP}}:8200}"
VAULT_CACERT="${VAULT_CACERT:-/opt/vault/certs/ca-cert.pem}"

# Export environment variables for vault command
export VAULT_ADDR
export VAULT_CACERT

# Check if secret_id file contains a wrapped token (starts with hvs.CAESI)
if [[ -f "$SECRET_ID_FILE" ]] && grep -q "^hvs\.CAESI" "$SECRET_ID_FILE"; then
    echo "Wrapped Secret ID detected, unwrapping..."
    
    # Read the wrapped token
    WRAPPED_TOKEN=$(cat "$SECRET_ID_FILE")
    
    # Unwrap the token to get the actual Secret ID
    UNWRAPPED_SECRET_ID=$(vault unwrap -field=secret_id "$WRAPPED_TOKEN" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$UNWRAPPED_SECRET_ID" ]]; then
        # Atomically replace the wrapped token with the unwrapped Secret ID
        echo "$UNWRAPPED_SECRET_ID" > "$SECRET_ID_FILE.tmp"
        mv "$SECRET_ID_FILE.tmp" "$SECRET_ID_FILE"
        echo "Secret ID successfully unwrapped and stored"
        
        # Set proper permissions
        chmod 600 "$SECRET_ID_FILE"
        chown vault-agent:vault-agent "$SECRET_ID_FILE"
    else
        echo "Failed to unwrap Secret ID - using existing content"
        exit 1
    fi
else
    echo "No wrapped token found - using existing Secret ID"
fi

# Verify the secret ID file exists and is readable
if [[ ! -f "$SECRET_ID_FILE" ]]; then
    echo "ERROR: Secret ID file not found at $SECRET_ID_FILE"
    exit 1
fi

if [[ ! -r "$SECRET_ID_FILE" ]]; then
    echo "ERROR: Secret ID file is not readable"
    exit 1
fi

echo "Secret ID verification completed"
