# Allow Ansible to manage AppRole policies and secrets
path "auth/approle/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow Ansible to create and manage policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow Ansible to manage KV secrets
path "kv/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow Ansible to renew secrets and tokens
path "sys/renew/*" {
  capabilities = ["update"]
}

# Allow Ansible to lookup token information
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Super user capabilities for lab environment
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
