#!/bin/bash
# PostgreSQL Connection Script
# Скрипт для подключения к PostgreSQL серверу

set -e

POSTGRESQL_IP="${postgresql_ip}"
SSH_KEY_PATH="${ssh_key_path}"

echo "Connecting to PostgreSQL server at $POSTGRESQL_IP"
echo "Using SSH key: $SSH_KEY_PATH"

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "ERROR: SSH key file not found: $SSH_KEY_PATH"
    exit 1
fi

# Подключение по SSH
ssh -i "$SSH_KEY_PATH" ubuntu@$POSTGRESQL_IP 