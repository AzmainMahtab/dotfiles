#!/usr/bin/env bash
# One-time root setup so theme changes reach a running Brave.
#   sudo ./install.sh            (run from this directory or via install.sh)
set -euo pipefail

[[ "$EUID" -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
user="${SUDO_USER:?run via sudo from your own user}"
home="$(getent passwd "$user" | cut -d: -f6)"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -m 755 "$here/brave-theme-sync" /usr/local/bin/brave-theme-sync
for unit in brave-theme-sync.service brave-theme-sync.path; do
    sed "s#@HOME@#$home#g" "$here/$unit" > "/etc/systemd/system/$unit"
done

# Replace the old symlink with a real file written by the helper.
rm -f /etc/brave/policies/managed/theme.json
systemctl daemon-reload
systemctl enable --now brave-theme-sync.path
if [[ -f "$home/.config/theme-active/brave-policy.json" ]]; then
    systemctl start brave-theme-sync.service
fi
echo "brave-theme-sync installed"
