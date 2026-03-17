#!/bin/bash
# Dynamic Ansible inventory script that queries OpenTofu outputs

set -euo pipefail

cd "$(dirname "$0")/../infrastructure"

PUBLIC_IP=$(tofu output -raw public_ip_address 2>/dev/null || echo "")

if [ -z "$PUBLIC_IP" ]; then
    echo "Error: Could not retrieve public IP from OpenTofu outputs" >&2
    exit 1
fi

cat <<EOF
[sourcecontrol-vm]
$PUBLIC_IP ansible_user=azureuser ansible_port=443
EOF
