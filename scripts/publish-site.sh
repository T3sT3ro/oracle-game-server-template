#!/usr/bin/env bash
# Upload a static website (for example an Astro build) to the server, over Tailscale.
#
# Usage: scripts/publish-site.sh <site> <folder>
#   <site>    the `static:` name of the site in vars.yml, e.g. blog
#   <folder>  the built site, e.g. ~/code/blog/dist  (must contain index.html)
#
# Files that no longer exist locally are deleted on the server too.
# Env overrides: SSH_KEY (default ~/.ssh/id_ed25519), TS_HOST (default: tailscale_hostname from vars.yml)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

VARS_FILE=ansible/group_vars/all/vars.yml

die() { echo "error: $*" >&2; exit 1; }
var() { sed -nE "s/^$1:[[:space:]]*\"?([^\"#]+)\"?.*/\1/p" "$VARS_FILE" | sed 's/[[:space:]]*$//'; }

[[ $# -eq 2 ]] || { sed -n '4,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
site=$1
folder=${2%/}

[[ "$site" =~ ^[a-z0-9-]+$ ]] || die "site name must be lowercase letters, digits or dashes"
[[ -f "$folder/index.html" ]] || die "$folder/index.html not found (build the site first)"
[[ -f "$VARS_FILE" ]] || die "$VARS_FILE missing"

host="${TS_HOST:-$(var tailscale_hostname)}"
data="$(var data_mount_point)"
data="${data:-/mnt/data}"
key="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
[[ -n "$host" ]] || die "tailscale_hostname not set in $VARS_FILE (or set TS_HOST)"

rsync -az --delete -e "ssh -i $key" "$folder/" "ubuntu@$host:$data/sites/$site/"
echo "Published $folder as '$site'."
