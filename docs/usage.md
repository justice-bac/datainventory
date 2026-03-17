# Usage

## First Deployment
To deploy the self-hosted source control system for the first time, follow these steps:
1. **Generate SSH Keys**: If you haven't already, generate SSH keys for secure access.
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""   
   ```
2. **Authenticate to Azure and select the target subscription**: Use Azure CLI as the source of truth for the active subscription.
   ```bash
   az login
   ```
   
   > [!NOTE]If your account has access to multiple subscriptions, select the one you want to deploy into.
   > ```bash
   >az account set --subscription your-subscription-id-or-name"
   >
   > az account set --subscription "your-subscription-id-or-name"
   >```
   The devcontainer shell maps the active Azure CLI subscription into `ARM_SUBSCRIPTION_ID` for OpenTofu. In an existing shell, run this once after login or subscription changes.
   ```bash
   export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
   ```
   
   Confirm the active subscription if needed.

   ```bash
   az account show --query '{name:name,id:id}' -o table
   ```   

3. **Initialize OpenTofu**:    
   Initialize and apply the OpenTofu configuration. The first apply uses the local state file so it can create the remote state storage resources.  

   Navigate to the infrastructure directory and initialize the backend.
   ```bash
   cd infrastructure
   tofu init
   ```
4. **Apply the Infrastructure Configuration**: Apply the configuration to create the required Azure resources.
   ```bash
   tofu apply
   ```
5. **Migrate OpenTofu State to Azure Storage**: After the first apply, move state off the local file and into the Azure backend created by that apply.
   ```bash
   bash migrate-state-to-azure.sh
   ```
6. **Create the Azure Key Vault Secret**: Export the generated Key Vault name and create the database password secret.
   ```bash
   export AZURE_KEY_VAULT_NAME="$(tofu output -raw key_vault_name)"
   az keyvault secret set --vault-name "$AZURE_KEY_VAULT_NAME" --name ckan-db-password --value 'choose-a-strong-password'
   ```
7. **Create the Ansible Inventory**: Create `ansible/inventory.ini` with the `inventory.sh` script.   
   ```bash
   cd /workspace/ansible
   ansible-playbook -i inventory.sh main.yml
   ```
8. **Configure the VM with Ansible**: Run the playbook after OpenTofu finishes so the host configuration is applied using the password stored in Azure Key Vault.
   ```bash
   ansible-playbook main.yml
   ```

## Subsequent Deployments
For later changes, use the smallest deployment path that matches what changed:
1. **Application or configuration-only changes**: Re-export the Key Vault name in a fresh shell, then re-run Ansible against the existing VM.
   ```bash
   cd /workspace/infrastructure
   export AZURE_KEY_VAULT_NAME="$(tofu output -raw key_vault_name)"
   cd /workspace/ansible
   ansible-playbook main.yml
   ```
2. **Infrastructure changes**: Re-run OpenTofu, refresh the exported Key Vault name, then run Ansible again.
   ```bash
   cd /workspace/infrastructure
   tofu init
   tofu apply
   export AZURE_KEY_VAULT_NAME="$(tofu output -raw key_vault_name)"
   cd /workspace/ansible
   ansible-playbook main.yml
   ```
3. **Secret rotation**: Re-export the Key Vault name if needed, update the Azure Key Vault secret, then re-run Ansible.
   ```bash
   cd /workspace/infrastructure
   export AZURE_KEY_VAULT_NAME="$(tofu output -raw key_vault_name)"
   az keyvault secret set --vault-name "$AZURE_KEY_VAULT_NAME" --name ckan-db-password --value 'choose-a-strong-password'
   cd /workspace/ansible
   ansible-playbook main.yml
   ```

## Automated VM Scheduling

The infrastructure includes Azure Automation to automatically stop and start the VM on a schedule, reducing costs for non-production environments:

- **Stop**: Daily at 7:00 PM EST
- **Start**: Daily at 7:00 AM EST

This is managed by:
- Azure Automation Account with system-assigned managed identity
- Two PowerShell runbooks (Start-VM and Stop-VM)
- Two daily schedules in the America/New_York timezone

To disable or modify the schedule:
1. Update the schedule resources in `infrastructure/automation.tf`
2. Run `tofu apply` to update the schedules

To manually start/stop outside the schedule:
```bash
# Stop the VM
az vm deallocate --resource-group sourcecontrol --name sourcecontrol-vm

# Start the VM
az vm start --resource-group sourcecontrol --name sourcecontrol-vm
```

> **Note**: The VM will be unreachable during stopped hours. Plan maintenance and deployments accordingly.

