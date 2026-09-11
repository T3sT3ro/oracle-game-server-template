# Pelican Panel Infrastructure on OCI

Automated, reproducible infrastructure-as-code (IaC) deployment for [Pelican Panel](https://pelican.dev/) on Oracle Cloud Infrastructure (OCI) using Terraform, Ansible, Docker, and Caddy.

---

## 📌 Project Status

| Component | Status | Notes |
| :--- | :--- | :--- |
| **Local Environment** | 🟡 **Semi-Tested** | Tested via local Docker runner (`./test-local.sh`). DB seeding and proxy routing verified. |
| **OCI Production** | 🔴 **Untested** | Infrastructure defined in Terraform/Ansible; awaiting end-to-end cloud deployment. |
| **Setup Pipeline** | 🛠 **Manual Transition** | WIP — for now manual wizard step-by-step deployment. |

---

## 📦 Prerequisites

- Only nix — it will install all the necessary dependencies for local development and testing.
  - Recommended [nix installer by Determinate](https://determinate.systems/blog/determinate-nix-installer/), because it comes with preconfigured flakes and modern CLI enabled.
  - After installing, use `nix develop` in the root to enter the development environment.

---

## 🏗 Architecture Overview

The stack is fully decoupled into single-purpose Docker containers communicating over an isolated bridge network (`pelican-net`):

* **Caddy** (`caddy:2-alpine`): Edge reverse proxy with automated TLS termination and static routing.
* **Pelican Panel** (`ghcr.io/pelican/panel:latest`): PHP-FPM / HTTP web interface listening on internal port 80.
* **MariaDB** (`mariadb:10.11`): Primary relational database storage for application data.
* **Redis** (`redis:7-alpine`): In-memory cache and queue driver for background workers.
* **Dozzle** (`amir20/dozzle:latest`): Zero-overhead live log streaming web dashboard.

---

## 🔐 Ansible Vault Configuration

Sensitive parameters (passwords, secret keys) are encrypted using **Ansible Vault**.

### 1. Create a Vault Password File
Create a password file locally (ensure it is listed in `.gitignore`):

```bash
openssl rand -base64 32 > ansible/.vault_pass
chmod 600 ansible/.vault_pass
```

### 2. Create or Edit the Encrypted Vault File
Create the encrypted variables file at `ansible/group_vars/all/vault.yml`:

```bash
ansible-vault create ansible/group_vars/all/vault.yml --vault-password-file ansible/.vault_pass
```

If the file already exists, edit it using:

```bash
ansible-vault edit ansible/group_vars/all/vault.yml --vault-password-file ansible/.vault_pass
```

### 3. Required Vault Fields
Ensure your `ansible/group_vars/all/vault.yml` contains the following key-value pairs:

```yaml
# Admin Credentials
vault_admin_password: "..."

# MariaDB Credentials
vault_db_password: "..."
vault_db_root_password: "..."

# Optional Application Keys
vault_app_key: "base64:..."
vault_admin_email: "..."
```

> [!WARNING]
> Ensure that your vault password file (`.vault_pass`) is kept secure and never committed to version control.
> Change your passwords — use `openssl rand -base64 32` to generate secure random values and use them in your vault file instead of current `...` placeholders.

---

## 💻 Local Development & Testing

A local Docker-in-Docker / Compose test environment allows validating Ansible playbooks and container configurations without provisioning OCI resources.

### 1. Update Host File Resolution
Add local test hostnames to `/etc/hosts` on your host machine:

```bash
127.0.0.1 panel.example.com web.example.com logs.example.com
```

#### 2. Custom Domain Configuration (Production)
Define your root domain in `ansible/group_vars/all/vars.yml` or your inventory file:

```yaml
domain_name: "yourdomain.com"
```

#### 3. Execute Local Test Suite
Run the local orchestration script to provision test containers and execute the playbook:

```bash
./test-local.sh
```

Or manually manage the local test environment:

```bash
# Start test environment
docker compose -f tests/docker-compose.local.yml up -d

# Run local Ansible playbook
ansible-playbook -i tests/inventory.local.yml ansible/playbook.yml --vault-password-file ansible/.vault_pass
```

#### 4. Verify Local Services
Open your browser and navigate to the local endpoints (accept self-signed TLS certificates):

* **Pelican Panel:** `https://panel.<yourdomain>`
* **Web Server Endpoint:** `https://web.<yourdomain>` — for hosting your own web content like static websites or web applications.
* **Dozzle Log Dashboard:** `https://logs.<yourdomain>`

#### 5. Reset Local Environment
To wipe container state and purge volume storage:

```bash
docker compose -f tests/docker-compose.local.yml down -v
```

---

## 🚀 OCI Production Deployment

### 1. Provision Cloud Infrastructure (Terraform)
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Run Ansible Deployment
Deploy the container stack and execute automated migrations:

```bash
cd ../ansible
ansible-playbook -i inventory.ini playbook.yml --vault-password-file ../ansible/.vault_pass
```

---

## 🔍 Troubleshooting & Logs

Log streaming is available via Dozzle at `https://logs.<your-domain>`. 

To manually inspect container logs via CLI on the remote host:

```bash
# Tail Pelican Panel logs
docker logs -f app-pelican-panel-1

# Tail Caddy reverse proxy logs
docker logs -f app-caddy-1

# Tail MariaDB logs
docker logs -f app-pelican-db-1
```
