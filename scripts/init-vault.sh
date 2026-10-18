#!/usr/bin/env bash
# Creates ansible/group_vars/all/vault.yml, or adds whatever keys are missing from it.
# Existing values are never changed or printed. Generated secrets only touch disk
# encrypted (plaintext stays in a RAM-backed temp dir and is deleted on exit).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

VAULT=ansible/group_vars/all/vault.yml
PASS=ansible/.vault_pass
umask 077

if [[ ! -f "$PASS" ]]; then
  openssl rand -base64 32 > "$PASS"
  echo "Created $PASS. Store a copy in your password manager."
fi
chmod 600 "$PASS"

tmpdir="$(mktemp -d -p /dev/shm 2>/dev/null || mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
plain="$tmpdir/vault.yml"

if [[ -f "$VAULT" ]]; then
  ansible-vault view --vault-password-file "$PASS" "$VAULT" > "$plain"
else
  : > "$plain"
fi

added=0
add() {
  local key=$1 value=$2
  if ! grep -qE "^${key}:" "$plain"; then
    printf '%s: "%s"\n' "$key" "$value" >> "$plain"
    echo "  + $key"
    added=$((added + 1))
  fi
}
password() { openssl rand -base64 48 | tr -d '/+=\n' | cut -c1-32; }

add vault_calagopus_encryption_key "$(openssl rand -hex 32)"
add vault_postgres_password "$(openssl rand -hex 24)"
add vault_valkey_password "$(openssl rand -hex 24)"
add vault_calagopus_admin_password "$(password)"
add vault_grafana_admin_password "$(password)"
add vault_beszel_admin_password "$(password)"

if ! grep -qE '^vault_tailscale_authkey:' "$plain" && [[ -t 0 ]]; then
  echo "Tailscale auth key: admin console → Settings → Keys → reusable: no, pre-approved,"
  echo "tags: tag:gameserver. Leave empty to add it later."
  read -rsp "Auth key: " ts_key; echo
  [[ -n "$ts_key" ]] && add vault_tailscale_authkey "$ts_key"
fi

# The Turnstile secret is only needed once vars.yml turns the login captcha on.
VARS="$(dirname "$VAULT")/vars.yml"
if grep -qE '^calagopus_captcha_provider: *"?turnstile' "$VARS" 2>/dev/null \
  && ! grep -qE '^vault_turnstile_secret_key:' "$plain" && [[ -t 0 ]]; then
  echo "Turnstile secret key: Cloudflare dashboard → Turnstile → your widget → Secret key."
  read -rsp "Secret key: " ts_secret; echo
  [[ -n "$ts_secret" ]] && add vault_turnstile_secret_key "$ts_secret"
fi

legacy="$(grep -oE '^(vault_mysql_[a-z_]+|vault_app_key|vault_admin_password):' "$plain" | tr -d ':' | paste -sd' ' || true)"
[[ -n "$legacy" ]] && echo "Note: unused legacy keys still in the vault: $legacy (safe to delete with ansible-vault edit)."

if (( added > 0 )); then
  ansible-vault encrypt --vault-password-file "$PASS" --output "$VAULT" "$plain" >/dev/null
  echo "Vault updated ($added key(s) added)."
else
  echo "Vault already complete; nothing changed."
fi

echo "Back up APP_ENCRYPTION_KEY separately from DB backups:"
echo "  ansible-vault view --vault-password-file $PASS $VAULT | grep encryption_key"
