# Calagopus Game Server Infrastructure on OCI

Automated, reproducible infrastructure-as-code (IaC) deployment for [Calagopus](https://github.com/calagopus) on Oracle Cloud Infrastructure (OCI) using Terraform, Ansible, Docker, and Caddy.

---

## 📌 Project Status

| Component | Status | Notes |
| :--- | :--- | :--- |
| **OCI Infrastructure** | 🟢 **Ready** | Fully automated via Terraform (Ampere A1 Flex + Block Storage). |
| **Ansible Automation** | 🟢 **Ready** | Handles host volume formatting, Docker stack, and zero-touch panel migrations. |
| **Edge Proxy** | 🟢 **Ready** | Caddy reverse proxy with automatic TLS certificate management. |

---

## 📦 Prerequisites

- **Nix Flake Environment** (Recommended): Run `nix develop` to enter a shell pre-configured with Terraform, Ansible, OpenSSH, and JQ.
- **OCI Account & Credentials**: Active tenancy with API key access and user OCIDs configured.

---

## 🏗 Architecture Overview

The application stack communicates over an isolated Docker bridge network (`calagopus-net`):

* **Caddy** (`caddy:2-alpine`): Reverse proxy handling TLS termination and routing.
* **Calagopus Panel** (`ghcr.io/calagopus/panel:latest`): Primary web administration panel.
* **MariaDB** (`mariadb:10.11`): Relational storage for application state.
* **Redis** (`redis:7-alpine`): In-memory caching and background job worker queues.
* **Dozzle** (`amir20/dozzle:latest`): Lightweight web dashboard for container logs.

---

## 🔐 Ansible Vault Setup

1. Create a vault password file (ensure permissions are restricted):
   
```bash
openssl rand -base64 32 > ansible/.vault_pass
chmod 600 ansible/.vault_pass
```

2.  Create ansible/group_vars/all/vault.yml:

```bash
ansible-vault create ansible/group_vars/all/vault.yml --vault-password-file ansible/.vault_pass
```

3. Ensure the following keys exist in vault.yml:

```yaml
vault_admin_password: "YourSecureAdminPassword"
vault_mysql_password: "YourDatabasePassword"
vault_mysql_root_password: "YourRootDatabasePassword"
vault_app_key: "base64:YourGenerated32ByteKey="
vault_mysql_database: "calagopus"
vault_mysql_user: "calagopus"
```

---

## 🚀 Quick Start Deployment
Execute the all-in-one deployment script to provision cloud resources and trigger Ansible:

```bash
./deploy.sh
```
🔄 Re-Imaging & Clean State Workflows
To wipe host application state and re-verify zero-touch provisioning without destroying OCI network interfaces:

```bash
# 1. Re-image instance via OCI CLI
oci compute instance action --action REIMAGE --instance-id <YOUR_INSTANCE_OCID>

# 2. Re-apply Ansible playbook once SSH is available
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --vault-password-file ansible/.vault_pass
```