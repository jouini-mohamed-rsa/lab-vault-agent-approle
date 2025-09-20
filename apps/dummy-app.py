#!/usr/bin/env python3

import time
import os
import json
from pathlib import Path

CONFIG_FILE = "/opt/vault-agent/secrets/secret.json"
LOG_FILE = "/opt/vault-agent/logs/dummy-app.log"

def log_message(msg):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] {msg}"
    print(log_entry)
    
    Path(LOG_FILE).parent.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(log_entry + "\n")

def read_config():
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                content = f.read().strip()
                log_message(f"Config file read: {len(content)} characters")
                
                # Parse JSON format from Vault Agent template
                config = json.loads(content)
                log_message(f"Parsed JSON config with keys: {list(config.keys())}")
                return config
        else:
            log_message(f"Config file not found: {CONFIG_FILE}")
            return {}
    except json.JSONDecodeError as e:
        log_message(f"Error parsing JSON config: {e}")
        return {}
    except Exception as e:
        log_message(f"Error reading config: {e}")
        return {}

def main():
    log_message("🚀 Dummy application started - monitoring for secret updates")
    log_message(f"Monitoring file: {CONFIG_FILE}")
    
    last_config = {}
    
    while True:
        try:
            current_config = read_config()
            
            # Check if config changed
            if current_config != last_config:
                log_message("🔄 Configuration changed!")
                
                if current_config:
                    # Mask sensitive values for logging
                    masked_config = {}
                    for k, v in current_config.items():
                        if len(v) > 8:
                            masked_config[k] = f"{v[:4]}...{v[-4:]}"
                        else:
                            masked_config[k] = "***"
                    log_message(f"✅ New config applied: {masked_config}")
                    
                    # Simulate application using the secrets
                    if 'api_key' in current_config:
                        log_message(f"🔑 Using API key for authentication")
                    if 'database_url' in current_config:
                        log_message(f"💾 Connecting to database")
                    if 'api_secret' in current_config:
                        log_message(f"🔐 API secret configured")
                        
                else:
                    log_message("⚠️  Config is empty or unavailable")
                
                last_config = current_config
            
            time.sleep(10)  # Check every 10 seconds
            
        except KeyboardInterrupt:
            log_message("🛑 Application shutting down gracefully")
            break
        except Exception as e:
            log_message(f"❌ Unexpected error: {e}")
            time.sleep(30)

if __name__ == "__main__":
    main()
