#!/usr/bin/env bash
set -e

# 1. Provision Infrastructure via Terraform
echo "==> Applying Terraform configuration..."
cd terraform
terraform init
terraform apply -auto-approve
SERVER_IP=$(terraform output -raw public_ip)
cd ..

echo "==> OCI Provisioning Complete. Target IP is: $SERVER_IP"
echo "==> Waiting 30 seconds for SSH daemon initialization..."
sleep 30

# 2. Configure Host and Deploy Services via Ansible
echo "==> Initiating Ansible Configuration..."
cd ansible

# Run Ansible using the dynamically supplied IP and prompt for Vault password interactively
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
    -i "$SERVER_IP," \
    -u ubuntu \
    --private-key ~/.ssh/id_rsa \
    --ask-vault-pass \
    playbook.yml

echo "==> Deployment complete! Access your panel to complete the OOBE setup wizard."