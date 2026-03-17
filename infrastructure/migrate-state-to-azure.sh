#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$script_dir"

if ! command -v tofu >/dev/null 2>&1; then
    echo "tofu is required but not installed." >&2
    exit 1
fi

if ! command -v az >/dev/null 2>&1; then
    echo "az is required but not installed." >&2
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo "Run 'az login' before migrating state." >&2
    exit 1
fi

state_file="terraform.tfstate"

if [[ ! -f "$state_file" ]]; then
    echo "Local state file '$state_file' was not found. Run 'tofu apply' with local state before migrating." >&2
    exit 1
fi

read_state_output() {
    local output_name="$1"

    python3 - "$state_file" "$output_name" <<'EOF'
import json
import sys

state_path = sys.argv[1]
output_name = sys.argv[2]

with open(state_path, encoding="utf-8") as handle:
    state = json.load(handle)

try:
    value = state["outputs"][output_name]["value"]
except KeyError:
    sys.exit(1)

if not isinstance(value, str):
    sys.exit(1)

print(value)
EOF
}

resource_group_name="$(read_state_output terraform_state_resource_group_name)" || {
    echo "terraform_state_resource_group_name was not found in local state. Run 'tofu apply' first." >&2
    exit 1
}
storage_account_name="$(read_state_output terraform_state_storage_account_name)" || {
    echo "terraform_state_storage_account_name was not found in local state. Run 'tofu apply' first." >&2
    exit 1
}
container_name="$(read_state_output terraform_state_container_name)" || {
    echo "terraform_state_container_name was not found in local state. Run 'tofu apply' first." >&2
    exit 1
}
state_key="$(read_state_output terraform_state_key)" || {
    echo "terraform_state_key was not found in local state. Run 'tofu apply' first." >&2
    exit 1
}

if [[ ! -f backend.tf ]]; then
    cat > backend.tf <<'EOF'
terraform {
    backend "azurerm" {}
}
EOF
fi

tofu init \
    -migrate-state \
    -backend-config="resource_group_name=${resource_group_name}" \
    -backend-config="storage_account_name=${storage_account_name}" \
    -backend-config="container_name=${container_name}" \
    -backend-config="key=${state_key}" \
    -backend-config="use_azuread_auth=true"