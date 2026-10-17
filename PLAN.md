# Plan: finish the Calagopus server template

Status snapshot: **2026-10-17**. Tick boxes as work lands; keep the status table honest.
The full explanation of the design is in [docs/GUIDE.md](docs/GUIDE.md); update it with the code.
Priorities: **security** and **analytics/observability** first, then convenience.

---

## 1. Where things stand

### Live environment (deployed 2026-10-18)

- `deploy.sh infra` and `bootstrap`/`configure` have run. A full `configure` run is clean and
  idempotent (`ok=81 changed=0 failed=0`).
- Running: panel + Wings (AIO), Postgres, Valkey, Caddy, Grafana, Loki, Alloy, Beszel hub and
  agent, socket proxy. Admin created, registration off, setup wizard closed, telemetry off.
- Admin access over Tailscale: `ssh ubuntu@calagopus`, Grafana `https://logs.<tailnet>.ts.net`,
  Beszel `https://status.<tailnet>.ts.net` (Tailscale Services; until deployed: `:8443`/`:8444`).
- **Still open:**
  - Close public SSH: `./deploy.sh infra` removes the `SSH bootstrap` rule.
  - DNS `A` record `panel` → server, for the HTTPS certificate.
  - Remove the stale `/etc/hosts` line on the laptop.
  - First panel login + 2FA, allocations, Beszel alerts.

### Code status (2026-10-16, first implementation pass)

Legend: ✅ implemented + validated locally · 🟡 implemented, needs the real host · ⬜ not started

| Area | Where | State | Notes |
| :--- | :--- | :--- | :--- |
| Network perimeter | `oci/network.tf` | 🟡 | 80/443/2022 + `game_port_range` public; SSH only from the VCN (+ bootstrap CIDRs); 41641/udp for Tailscale; 8080 gone. `terraform validate` ✅ |
| Compute | `oci/compute.tf` | 🟡 | Image-replacement footgun fixed (`ignore_changes`); monitoring + Bastion agent plugins on |
| Storage | `oci/storage.tf` | 🟡 | Consistent device path (attachment gets replaced once); weekly backups, ≤4 kept |
| Alarms | `oci/monitoring.tf` | 🟡 | Instance down (no metrics) and memory → email topic. No CPU alarm (game servers run hot legitimately) |
| Deploy flow | `deploy.sh` | ✅ | `infra` / `bootstrap` / `configure`; plan + confirm; shellcheck clean |
| Secrets | `scripts/init-vault.sh` | ✅ | Generates missing secrets without printing them; `.vault_pass` now 600. **Not run yet** |
| Host hardening | `roles/base`, `roles/firewall` | 🟡 | sshd drop-in (validated before reload), unattended upgrades + reboot window, sysctls, UFW removed, metadata service blocked for containers |
| Data volume | `roles/storage` | 🟡 | Label mount + `prjquota`, refuses foreign filesystems, Docker requires the mount |
| Docker | `roles/docker` | 🟡 | `local` log driver with caps, `live-restore`, address pools clear of Wings/VCN |
| Tailscale | `roles/tailscale` | 🟡 | Tagged join via key file; dashboards as Tailscale Services `logs` (Grafana) and `status` (Beszel); fails fast if HTTPS certs are off |
| Calagopus stack | `roles/calagopus` | ✅ | AIO + Postgres 18 + Valkey, digest-pinned. Locally tested with the standalone image: `/.env` loading, secrets absent from `docker inspect`, idempotent bootstrap (3 changes → 0), registration blocked, wizard closed, admin API returns 403 until 2FA, HTTP→HTTPS, token redaction in access logs |
| Wings on AIO | `roles/calagopus` | 🟡 | Data on the volume at identical paths; `xfs_quota` via `SYS_ADMIN` + device; smoke test checks quotas on the host |
| Websites + apps | `roles/web`, `apps/`, `scripts/publish-site.sh` | ✅ | Caddy in its own role. One `sites:` list (static / proxy / redirect), apps as plain compose folders, blog upload over Tailscale. Locally tested, see below |
| Monitoring stack | `roles/observability` | ✅ | Beszel + Grafana/Loki/Alloy + socket proxy (Dozzle dropped 2026-10-17). See the test notes below |
| Lint | — | ✅ | ansible-lint `production` profile: 0 findings; `terraform fmt`/`validate` pass |
| README | `README.md` | ✅ | Rewritten: setup, day-2, security model |

### Local test results (2026-10-17)

These ran on throwaway containers on a workstation, with all data in a scratch folder:

- **Panel bootstrap:** idempotent (3 changes on the first run, 0 on the second).
  Registration returns "registration is disabled". The admin API returns
  "two-factor authentication required" until 2FA is set up. HTTP redirects to HTTPS.
  No secrets show in `docker inspect`.
- **Config-hash recreates:** changing one Wings setting recreated only the panel container
  (db, cache and caddy kept running). An identical re-render recreated nothing. Changing Loki's
  retention recreated only Loki, and it loaded the new value.
- **Monitoring:**
  - Beszel reaches **up** over the unix socket alone (no token, no hub URL).
  - Loki receives docker, Caddy and journal logs, and Alloy logs no errors.
  - The Grafana dashboard and datasource are provisioned.
  - The socket proxy blocks writes.
- **Websites and apps** (second round):
  - Every site type works through Caddy over HTTPS: panel, static blog (`404.html` used when
    present), `www` redirect that keeps the path, an app on the web network, and a game web port
    on the Wings gateway IP. Unknown hostnames get no site.
  - Security headers are on every site.
  - App deploy is idempotent, and `secrets.env` is written with mode 600.
  - The panel ignores a forged `X-Forwarded-For` sent from another container. Through Caddy, it
    records Caddy's view of the client.
  - Bug found and fixed: the panel took Caddy's fixed IP. The web network now hands out
    automatic addresses only from its upper half (`web_ip_range`).
- **Lint:** ansible-lint (production profile) 0 findings; `terraform fmt` and `validate` pass;
  shellcheck passes.
- **Fixes found while writing the guide:**
  - `--tags calagopus` failed, and `--tags observability` set wrong URLs, because both relied on
    facts from other roles. Each role now looks them up itself.
  - `--check` crashed on skipped read-only lookups. They're now `check_mode: false`, and a dry
    run of bootstrap gives 0 failures and 0 changes.
  - Removed the leftover `remote-exec` provisioner. It would have failed creation of a fresh
    instance, because SSH isn't open then.
- **Bugs found during the real deploy (all fixed and committed):**
  - `ansible_managed` is undefined in `copy: content:` on ansible-core 2.21 (storage role).
  - `deploy.sh` didn't pass the ephemeral key passphrase to `apply tfplan`.
  - The quota smoke test checked `/mnt/data`, which isn't a mount point inside the container.
  - Ansible reset `/mnt/data/postgres` to root on the second run and locked Postgres out. Now
    created as uid 70.
  - community.crypto's `openssh_keypair` failed with `chattr` on XFS. Replaced with `ssh-keygen`.
- **Not tested locally:** the AIO image itself (it needs the real Docker socket), Wings, XFS
  quotas, Tailscale and the firewall. These are in the "verify on the real host" list.

### Free-tier compliance (checked 2026-10-17)

- 🟢 The server stays at **4 OCPU / 24 GB**. Oracle's docs list 2 OCPU / 12 GB for Always
  Free–only accounts since June 2026. Oracle support says Pay As You Go accounts keep 4/24.
  Terraform refuses anything bigger (validation in `oci/variables.tf`). The `free-tier-guard`
  budget emails on the first real charge.
- 🟢 Everything added in this pass is free: alarms, alert emails, the backup policy, the Bastion
  plugin and the security list. See the cost table in the README.
- [ ] Look in the Oracle console for leftover system disks from old experiments. They count
  toward the 200 GB.
- [ ] Check that `region` in `terraform.tfvars` is your home region. Free disk space only
  applies there.

### Must be verified on the real host (first `bootstrap` run)

- [x] `xfs_quota` works from inside the AIO container (verified: accounting + enforcement ON on `wings/lib`).
- [x] `tailscale serve` coexists with Caddy on :443 (verified with :8443/:8444; Services use their own addresses).
- [ ] Boot order after a reboot: `nofail` mount + `RequiresMountsFor`, DOCKER-USER rules restored
      from `rules.v4`, Tailscale back up, serve config persisted.
- [ ] A game server on a `0.0.0.0` allocation in `game_port_range` is reachable; SFTP on 2022.
- [x] Alloy reads the host journal (Loki has `docker`, `caddy`, `journal`, `wings`).
- [ ] Caddy reaches a game server's web port on `172.18.0.1:<port>` on the server's Docker
      version (tested locally on Docker 28 with a stand-in network).
- [ ] Moving the apex domain from GitHub Pages to the server: change its `A` records, then publish the blog.
- [ ] Unattended Docker upgrade with `live-restore` keeps game servers running.

---

## 2. What Calagopus actually needs (from upstream docs/compose)

- **Images:** `ghcr.io/calagopus/panel:aio` (Panel and Wings in one container; upstream recommends
  it for single-node setups), `ghcr.io/calagopus/pgautoupgrade:18-alpine` and `ghcr.io/calagopus/valkey`.
  The images are cosign-signed and ship SBOMs and provenance.
- **Env:** `DATABASE_URL`, `REDIS_URL`, `APP_ENCRYPTION_KEY` (required), `APP_TRUSTED_PROXIES`,
  `DATABASE_MIGRATE=true`, `PORT=8000`. `APP_ENCRYPTION_KEY` encrypts node tokens, OAuth secrets,
  backup credentials and TOTP seeds. Anyone with the key and a DB backup can decrypt all of them,
  and losing the key makes them unusable.
- **AIO mounts:** the Docker socket, plus `/var/lib/calagopus-wings`, `/etc/calagopus-wings` and
  `/var/log/calagopus-wings` at **identical paths** inside and out. `wings-config.yml` must exist
  as a *file* before the first start.
- **Ports:** Wings traffic is proxied through the panel under `/wings-proxy/…`, so 8080 is never
  published. SFTP on 2022 must stay public.
- **Headless admin bootstrap:** `panel-rs users create --admin true --password …` followed by
  `panel-rs oobe finish`. With these, the web wizard never has to be exposed.
- **Disk limits:** Wings supports `disk_limiter_mode: xfs_quota`. The block volume is already
  XFS; it needs the `prjquota` mount option.
- **Telemetry:** on by default, sending a daily report to calagopus.com. Turn it off in
  Admin → Settings → Telemetry.
- **Error tracking:** optional `SENTRY_URL`, which also works with a self-hosted, Sentry-compatible GlitchTip.

---

## 3. Target architecture

The system diagram (mermaid) is in the [README](README.md#how-it-fits-together). Details not
shown there:

- **Docker networks:**
  - `web`: Caddy (fixed IP), the panel and your apps. Created by the docker role. Automatic
    addresses come only from its upper half. The panel trusts forwarded IPs only from Caddy's address.
  - `backend`: the panel, Postgres and Valkey. Internal only, with no internet access.
  - `ops`: the monitoring tools. The Beszel agent uses the host network and talks to the hub
    over a unix socket.
- **Data volume (`/mnt/data`):** XFS, mounted by label, with project quotas for Wings disk
  limits. Holds `postgres/`, `valkey/`, `caddy/`, `calagopus/`, `wings/` and `observability/`.
- **Admin dashboards:** they listen on `127.0.0.1` only. `tailscale serve` publishes them on the
  tailnet as Tailscale Services: `https://logs.<tailnet>.ts.net` (Grafana) and
  `https://status.<tailnet>.ts.net` (Beszel).
- **SSH:** reachable over the tailnet, and from inside the VCN for OCI Bastion. It is closed to
  the internet.

---

## 4. Roadmap

> **Exposure gate:** Caddy (the only public HTTP entry) starts only after the admin exists,
> registration is off and the setup wizard is closed — enforced by `roles/calagopus/tasks/bootstrap.yml`.

### Phase 0: make the pipeline correct

- [x] `deploy.sh`: `infra` / `bootstrap` / `configure`, generated inventory, `accept-new` host keys,
      vault password file, plan + confirm instead of `-auto-approve`.
- [x] `compute.tf`: `ignore_changes` on image + metadata; instance OCID/private IP outputs.
- [ ] Reserved public IP so DNS survives re-creation, **only if the cost estimator shows $0** for it (not listed as Always Free).
- [x] `storage.tf`: consistent device path; weekly backup policy within the free backup count.
- [ ] Terraform state in an OCI Object Storage backend (or an encrypted off-laptop copy).
- [x] One source for exposed ports: `game_port_range` (Terraform output → `deploy.sh` → Ansible).
- [x] Playbook split into roles with tags.
- [x] Local lint: ansible-lint (`production`), `terraform fmt/validate`, shellcheck.
- [ ] CI (GitHub Actions) running those, plus `tflint` and `trivy config`.

### Phase 1: Calagopus stack

- [x] Storage role: label mount with `prjquota`, hard failure without the volume, Docker drop-in.
- [x] Wings data on the volume (identical paths); `xfs_quota` via `SYS_ADMIN` + device. *Verify on host.*
- [x] Compose: digest-pinned AIO, Postgres/Valkey passwords from the vault, internal backend
      network, panel not published (Caddy only), healthchecks, `stop_grace_period`.
- [x] Panel env as a mounted `/.env` (out of `docker inspect`); decryption cache off.
- [x] Caddy: ACME (staging switch), upstream headers/body limits, JSON access log with token redaction, no HTTP/3.
- [x] Headless admin bootstrap + wizard closed before exposure; idempotent (tested).
- [x] Wings base config (disk limiter, WebSocket cap) owned by Ansible, copied in at container start.
- [ ] DNS A record for `panel.<domain>` (manual) and remove the stale `/etc/hosts` lines.
- [x] Smoke test at the end of the play.
- [ ] Automate allocations for `game_port_range` (currently a manual step in the README).

### Websites and apps (done 2026-10-17)

- [x] `web` role: Caddy moved out of the Calagopus stack. It runs after the calagopus role, so
      the exposure gate still holds.
- [x] One `sites:` list in `vars.yml`: `static` (folder), `proxy` (app or game web port),
      `redirect`. A shared Caddy snippet gives every site the access log and headers.
- [x] `apps/<name>/compose.yml`: plain compose folders, listed in `apps:`, with secrets from
      `vault_app_env`. `apps/example/` documents the rules.
- [x] `scripts/publish-site.sh`: uploads a built static site over Tailscale.
- [x] Game web ports (Dynmap, BlueMap): an allocation on `172.18.0.1` plus a `proxy` site.
- [ ] Optional later: wildcard certificates via Porkbun DNS (custom Caddy build), and building
      and publishing the blog from CI.

### Phase 2: security hardening

- [x] Security list: public only 80/443/2022 + game range; SSH only from the VCN; 8080 removed.
- [x] Tailscale role: tagged pre-approved key via file, OpenSSH kept (not Tailscale SSH).
- [ ] Tailnet policy + optional Tailnet Lock (manual; snippet in README).
- [x] Admin UIs on loopback, published with `tailscale serve`.
- [x] Break-glass via OCI Bastion documented (Bastion agent plugin enabled).
- [x] Firewall: UFW removed, Oracle baseline kept, `tailscale0` + 41641/udp accepted, containers
      blocked from the metadata service (DOCKER-USER, persisted for reboots).
- [x] sshd hardening; unattended upgrades (Ubuntu + Docker + Tailscale) with reboot window; sysctls.
- [ ] **CrowdSec** (Caddy + sshd + panel-login scenario), firewall bouncer on `INPUT` + `DOCKER-USER`.
- [x] Images pinned by digest. [ ] Renovate for bump PRs. [ ] Optional `cosign verify` before rollout.
- [x] `no-new-privileges` everywhere, `cap_drop: [ALL]` where it works (Caddy, Valkey, Loki), read-only rootfs (Caddy, Loki, socket proxy).
- [x] Read-only socket proxy for monitoring tools.
- [x] Panel baseline enforced every run: registration off, 2FA for admins, telemetry off, HTTPS URL.
- [ ] CAPTCHA on login (Admin → Settings; needs a provider key).
- [x] `.vault_pass` 600; `init-vault.sh`. [ ] Run it; store vault password + encryption key in a password manager.

### Phase 3: observability and analytics (middle option)

- [x] OCI alarms (instance down, memory) → email. [ ] Confirm the subscription email after the first apply.
- [x] Beszel hub + agent, auto-provisioned system, data volume as extra filesystem.
- [ ] Beszel alert thresholds (disk > 80 %, memory, container down) + notification URL (D8).
- [x] Loki (30 d retention) + Alloy: container stdout, Caddy access log, Wings logs, journal.
- [x] Grafana with provisioned "Security overview" dashboard (login failures, statuses, top IPs, SSH events, container errors).
- [x] Live log tailing through Grafana (Dozzle dropped as a duplicate).
- [ ] Grafana alert rules (login-failure bursts, 5xx spikes) → D8 channel.
- [ ] CrowdSec decisions/bans panel once CrowdSec lands.

**Not now:** game/player analytics, web visitor analytics, Prometheus (upgrade path: CrowdSec and
Caddy already expose Prometheus metrics), GlitchTip via `SENTRY_URL`.

### Phase 4: backups and operations

Backups come in three layers (see README → Backups):

1. **Weekly OCI volume backup** of the whole data volume, kept 3 weeks. Restores everything at once.
2. **Calagopus backups** per game server, for restoring single worlds.
3. **Nightly database dump** of the panel.

- [x] Weekly OCI volume backup (Terraform).
- [ ] Calagopus System Backup Policy on the default "Local" configuration: daily, keep 3 daily +
      2 weekly, covering the Integrated Node. It's a manual UI step for now (README); automate
      it if the panel API allows.
- [ ] Postgres: nightly `pg_dump` sidecar to `/mnt/data/backups/postgres`.
- [ ] Copy outside Oracle for the most important worlds: Object Storage as a Calagopus target
      (a deduplicating driver like Restic or Kopia keeps it small). The free cap on PAYG is
      **10 GB Standard** (plus 10 GB Infrequent Access and 10 GB Archive) and
      **50,000 API requests/month**. Restic makes many requests, so count them first.
- [ ] Restore drill: restore one world from Calagopus, and the whole volume from an OCI backup.
      Write down the steps.
- [x] Update steps in the README (bump version + digest, run with `--tags`). [ ] Renovate.
- [x] README rewrite (plain language, mermaid diagram).

### Simplifications (done 2026-10-17)

- [x] Dropped Dozzle: Grafana tails live logs. One container, one tailnet port and the
      header-based login are gone.
- [x] Config-hash labels in both compose files replace the custom "which files changed" logic.
      A changed config file changes its service's label, and Compose recreates only that service.
- [x] Beszel connects only over the unix socket. No agent token, no hub URL.
- [x] Dropped the CPU alarm. "Instance down" and "memory" remain.
- [x] Tailscale serve: just re-runs the (idempotent) commands instead of parsing JSON status.
- [x] Panel settings: one SQL statement writes only the values that differ, instead of three
      tasks (read, compare, write).
- [x] Removed knobs nobody needs: `tailscale_direct_udp` (41641/udp is always open), and the
      `game_port_range` hand-off from Terraform to Ansible (Ansible never used it). As a result,
      `./deploy.sh configure` no longer needs Terraform or Oracle credentials.
- [ ] Later: use `CALAGOPUS_*` env vars for Wings settings instead of the copied base config
      and the entrypoint override. Check first that the Wings bundled in the AIO image supports them.

---

## 5. Decisions---

## 5. Decisions

| # | Decision | Choice | Status |
| :--- | :--- | :--- | :--- |
| D1 | What "analytics" covers | Server health and alerts, security events | decided 2026-10-16 |
| D2 | How admin UIs and SSH are reached | Tailscale: SSH and admin UIs on the tailnet only, OCI Bastion as break-glass | decided 2026-10-16 (was Authelia SSO) |
| D3 | Weight of the on-host observability stack | Middle: Beszel + Grafana/Loki/Alloy, plus free OCI alarms | decided 2026-10-16 (was lightweight); Dozzle dropped 2026-10-17 |
| D4 | Games and port ranges | One generic range (`game_port_range`, tcp+udp); allocations come from it | decided 2026-10-16 |
| D5 | DNS managed by Terraform (Porkbun) or by hand | By hand to start, Terraform later | default, not yet discussed |
| D6 | Calagopus telemetry | Off | default, not yet discussed |
| D8 | Alert delivery channel (Beszel + Grafana) | Discord webhook (no SMTP to run) | pending |
| D9 | Simplifications | Dropped Dozzle and the CPU alarm, config-hash recreates, Beszel over unix socket only | done 2026-10-17 |
| D10 | Server size on PAYG | 4 OCPU / 24 GB, Terraform guard at that size | decided 2026-10-17 |
| D11 | Websites and apps | `web` role, `sites:` list, `apps/` folders, blog at the apex via `publish-site.sh` | decided 2026-10-17 |
| D12 | Dashboard addresses | Tailscale Services `logs` (Grafana) and `status` (Beszel), no ports | decided 2026-10-18 |
