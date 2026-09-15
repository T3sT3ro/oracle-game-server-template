#!/usr/bin/env bash
set -e

echo "==> 1. Validating Terraform syntax and plan..."
cd terraform
terraform init -backend=false
terraform validate
cd ..

echo "==> 2. Spinning up local test container..."
docker compose -f tests/docker-compose.local.yml up -d

echo "==> 3. Running Ansible against local container target..."
cd ansible
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
    -i "oci_test_node," \
    -c docker \
    -u root \
    --vault-pass-file .vault_pass \
    playbook.yml
    # --ask-vault-pass \
cd ..

echo "==> Local deployment succeeded!"