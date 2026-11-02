#!/usr/bin/env bash
# One-time root setup so the login screen follows the desktop theme.
#   sudo ./install.sh            (run from this directory or via install.sh)
set -euo pipefail

[[ "$EUID" -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
user="${SUDO_USER:?run via sudo from your own user}"
home="$(getent passwd "$user" | cut -d: -f6)"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
themes="$here/../sddm/themes"

# Install the themes. The stock Catppuccin one normally comes from
# sddm-theme-catppuccin-git; it is only copied when that package is missing.
mkdir -p /usr/share/sddm/themes
for t in "$themes"/*/; do
    n="$(basename "$t")"
    if [[ "$n" == catppuccin-* && -d "/usr/share/sddm/themes/$n" ]]; then continue; fi
    rm -rf "/usr/share/sddm/themes/$n"
    cp -a "$t" "/usr/share/sddm/themes/$n"
done

install -m 755 "$here/sddm-theme-sync" /usr/local/bin/sddm-theme-sync
for unit in sddm-theme-sync.service sddm-theme-sync.path; do
    sed "s#@HOME@#$home#g" "$here/$unit" > "/etc/systemd/system/$unit"
done

systemctl daemon-reload
systemctl enable --now sddm-theme-sync.path
if [[ -f "$home/.config/theme-active/sddm-theme" ]]; then
    systemctl start sddm-theme-sync.service
fi
echo "sddm-theme-sync installed"
