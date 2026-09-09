#!/usr/bin/env bash
# Dotfiles installer for Arch-based systems running Hyprland.
# Run from inside the dotfiles repo:
#   ./install.sh
# Options:
#   -d, --dry-run      Show what would be done without making changes.
#   -c, --copy         Copy configs instead of symlinking (default: symlink).
#   -p, --no-packages  Skip package installation.
#   -s, --no-system    Skip system file installation (PAM files).
#   -y, --yes          Assume yes for interactive prompts (use with care).
#   -h, --help         Show this help message.

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
CONFIG_DIR="$DOTFILES_DIR/config"
LOCAL_DIR="$DOTFILES_DIR/local"
SYSTEM_DIR="$DOTFILES_DIR/system"
WALLPAPER_DIR="$DOTFILES_DIR/wallpapers"
HOME_FILES_DIR="$DOTFILES_DIR/home"
SHARE_DIR="$DOTFILES_DIR/share"

HOME_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
HOME_LOCAL_BIN="$HOME/.local/bin"
HOME_LOCAL_SHARE="${XDG_DATA_HOME:-$HOME/.local/share}"
HOME_WALLPAPERS="$HOME/Pictures/Wallpapers"

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
DRY_RUN=0
COPY_MODE=0
SKIP_PACKAGES=0
SKIP_SYSTEM=0
ASSUME_YES=0

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }
success() { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
usage() {
    sed -n '2,12p' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)      DRY_RUN=1; shift ;;
        -c|--copy)         COPY_MODE=1; shift ;;
        -p|--no-packages)  SKIP_PACKAGES=1; shift ;;
        -s|--no-system)    SKIP_SYSTEM=1; shift ;;
        -y|--yes)          ASSUME_YES=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Prompt helpers
# ---------------------------------------------------------------------------
confirm() {
    local prompt="$1"
    if [[ "$ASSUME_YES" -eq 1 ]]; then
        return 0
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
        return 1
    fi
    read -rp "$prompt [y/N] " answer
    case "$answer" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Distro / package manager detection
# ---------------------------------------------------------------------------
detect_pkg_manager() {
    if command -v paru >/dev/null 2>&1; then
        echo paru
    elif command -v yay >/dev/null 2>&1; then
        echo yay
    elif command -v pacman >/dev/null 2>&1; then
        echo pacman
    else
        echo none
    fi
}

PKG_MANAGER="$(detect_pkg_manager)"

# ---------------------------------------------------------------------------
# Backup helpers
# ---------------------------------------------------------------------------
backup_path() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            info "Would back up: $target -> $BACKUP_DIR/"
            return 0
        fi
        mkdir -p "$BACKUP_DIR"
        cp -a "$target" "$BACKUP_DIR/"
        success "Backed up: $target"
    fi
}

# ---------------------------------------------------------------------------
# Config installation (symlink or copy)
# ---------------------------------------------------------------------------
install_config_item() {
    local src="$1"
    local dst="$2"

    # Make sure parent directory exists
    local parent
    parent="$(dirname "$dst")"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        info "Would install config: $dst -> $src"
        return 0
    fi

    mkdir -p "$parent"

    if [[ -e "$dst" || -L "$dst" ]]; then
        # If it's already pointing to the right place, skip
        if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
            info "Already linked correctly: $dst"
            return 0
        fi
        backup_path "$dst"
        rm -rf "$dst"
    fi

    if [[ "$COPY_MODE" -eq 1 ]]; then
        cp -a "$src" "$dst"
        success "Copied: $dst"
    else
        ln -s "$src" "$dst"
        success "Linked: $dst -> $src"
    fi
}

install_configs() {
    info "Installing config directories/files into $HOME_CONFIG ..."

    # Install every directory/file in dotfiles/config as a peer of ~/.config
    for src in "$CONFIG_DIR"/*; do
        [[ -e "$src" ]] || continue
        local name
        name="$(basename "$src")"
        install_config_item "$src" "$HOME_CONFIG/$name"
    done
}

# ---------------------------------------------------------------------------
# Bare home dotfiles
#
# Files live in home/ without a leading dot (home/bashrc) and are installed
# as ~/.bashrc. Keeps the repo listing readable and avoids hidden files.
# ---------------------------------------------------------------------------
install_home_files() {
    if [[ ! -d "$HOME_FILES_DIR" ]]; then
        return 0
    fi

    info "Installing home dotfiles into $HOME ..."

    for src in "$HOME_FILES_DIR"/*; do
        [[ -e "$src" ]] || continue
        local name
        name="$(basename "$src")"
        install_config_item "$src" "$HOME/.$name"
    done
}

# ---------------------------------------------------------------------------
# XDG data files (custom .desktop entries referenced by mimeapps.list)
# ---------------------------------------------------------------------------
install_share_files() {
    if [[ ! -d "$SHARE_DIR/applications" ]]; then
        return 0
    fi

    info "Installing desktop entries into $HOME_LOCAL_SHARE/applications ..."
    mkdir -p "$HOME_LOCAL_SHARE/applications"

    for src in "$SHARE_DIR/applications"/*; do
        [[ -e "$src" ]] || continue
        local name
        name="$(basename "$src")"
        install_config_item "$src" "$HOME_LOCAL_SHARE/applications/$name"
    done

    if command -v update-desktop-database >/dev/null 2>&1 && [[ "$DRY_RUN" -eq 0 ]]; then
        update-desktop-database "$HOME_LOCAL_SHARE/applications" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Local scripts
# ---------------------------------------------------------------------------
install_local_scripts() {
    if [[ ! -d "$LOCAL_DIR/bin" ]]; then
        return 0
    fi

    info "Installing local scripts into $HOME_LOCAL_BIN ..."
    mkdir -p "$HOME_LOCAL_BIN"

    for src in "$LOCAL_DIR/bin"/*; do
        [[ -e "$src" ]] || continue
        local name
        name="$(basename "$src")"
        install_config_item "$src" "$HOME_LOCAL_BIN/$name"
        if [[ "$DRY_RUN" -eq 0 ]]; then
            chmod +x "$HOME_LOCAL_BIN/$name"
        fi
    done
}

# ---------------------------------------------------------------------------
# Wallpapers
# ---------------------------------------------------------------------------
install_wallpapers() {
    if [[ ! -d "$WALLPAPER_DIR" ]]; then
        return 0
    fi

    info "Installing wallpapers into $HOME_WALLPAPERS ..."

    if [[ "$DRY_RUN" -eq 1 ]]; then
        info "Would copy wallpapers to $HOME_WALLPAPERS"
        return 0
    fi

    mkdir -p "$HOME_WALLPAPERS"

    for src in "$WALLPAPER_DIR"/*; do
        [[ -e "$src" ]] || continue
        local name
        name="$(basename "$src")"
        cp -a "$src" "$HOME_WALLPAPERS/$name"
        success "Wallpaper: $name"
    done
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------
install_packages() {
    if [[ "$SKIP_PACKAGES" -eq 1 ]]; then
        info "Skipping package installation (--no-packages)."
        return 0
    fi

    if [[ ! -f "$DOTFILES_DIR/pkglist-explicit.txt" ]]; then
        warn "No pkglist-explicit.txt found; skipping packages."
        return 0
    fi

    info "Installing packages from pkglist-explicit.txt ..."

    case "$PKG_MANAGER" in
        paru|yay)
            if [[ "$DRY_RUN" -eq 1 ]]; then
                info "Would run: $PKG_MANAGER -S --needed - < $DOTFILES_DIR/pkglist-explicit.txt"
                return 0
            fi
            "$PKG_MANAGER" -S --needed - < "$DOTFILES_DIR/pkglist-explicit.txt"
            ;;
        pacman)
            # pacman cannot install AUR packages; filter them out.
            warn "Only pacman found; AUR packages from pkglist-aur.txt will be skipped."
            if [[ "$DRY_RUN" -eq 1 ]]; then
                info "Would run: pacman -S --needed - < $DOTFILES_DIR/pkglist-explicit.txt (minus AUR)"
                return 0
            fi
            grep -vxF -f "$DOTFILES_DIR/pkglist-aur.txt" "$DOTFILES_DIR/pkglist-explicit.txt" \
                | sudo pacman -S --needed -
            warn "Please install AUR packages manually or use paru/yay."
            ;;
        *)
            error "No supported package manager found (paru, yay, or pacman)."
            error "Install one of them and re-run, or use --no-packages."
            exit 1
            ;;
    esac

    success "Package installation complete."
}

# ---------------------------------------------------------------------------
# System file installation
# ---------------------------------------------------------------------------
install_system_files() {
    if [[ "$SKIP_SYSTEM" -eq 1 ]]; then
        info "Skipping system file installation (--no-system)."
        return 0
    fi

    if [[ ! -d "$SYSTEM_DIR" ]]; then
        return 0
    fi

    info "System PAM files are available in $SYSTEM_DIR."

    local install_pam=0
    if [[ "$ASSUME_YES" -eq 1 ]]; then
        install_pam=1
    elif confirm "Install/overwrite /etc/pam.d files?"; then
        install_pam=1
    fi

    if [[ "$install_pam" -eq 0 ]]; then
        info "Skipping PAM file installation."
        return 0
    fi

    install_system_file "$SYSTEM_DIR/pam-sudo" "/etc/pam.d/sudo"
    install_system_file "$SYSTEM_DIR/pam-hyprlock" "/etc/pam.d/hyprlock"

    # SDDM theme selection. The theme itself comes from the
    # sddm-theme-catppuccin-git package; this only selects it.
    install_system_file "$SYSTEM_DIR/sddm-theme.conf" "/etc/sddm.conf.d/theme.conf"

    # journald sync interval. The default (5m) loses the tail of the kernel log
    # when the machine hard-locks, which is exactly what happened during the
    # 2026-08-28 AnyDesk GPU lockup -- the journal stopped ~2 minutes before the
    # freeze. 1s makes amdgpu faults survive to disk.
    install_system_file "$SYSTEM_DIR/journald-crash-capture.conf" \
        "/etc/systemd/journald.conf.d/99-crash-capture.conf"
}

install_system_file() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$src" ]]; then
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        info "Would install system file: $dst <- $src"
        return 0
    fi

    mkdir -p "$BACKUP_DIR"

    # Destination directory may not exist yet on a fresh machine
    # (e.g. /etc/sddm.conf.d before sddm is configured).
    sudo mkdir -p "$(dirname "$dst")"

    if [[ -f "$dst" ]]; then
        sudo cp -a "$dst" "$BACKUP_DIR/" 2>/dev/null || true
        sudo cp "$src" "$dst"
    else
        sudo cp "$src" "$dst"
    fi
    success "System file installed: $dst"
}

# ---------------------------------------------------------------------------
# Post-install defaults
# ---------------------------------------------------------------------------
apply_defaults() {
    info "Applying desktop defaults ..."

    if command -v xdg-mime >/dev/null 2>&1; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            info "Would run: xdg-mime default nemo.desktop inode/directory"
        else
            xdg-mime default nemo.desktop inode/directory || warn "Failed to set default file manager"
        fi
    fi

    if command -v xdg-settings >/dev/null 2>&1; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            info "Would run: xdg-settings set default-web-browser brave-browser.desktop"
        else
            xdg-settings set default-web-browser brave-browser.desktop || warn "Failed to set default browser"
        fi
    fi

    # GTK4/libadwaita apps read the cursor from gsettings, not settings.ini.
    if command -v gsettings >/dev/null 2>&1; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            info "Would run: gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'"
        else
            gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' \
                || warn "Failed to set cursor theme"
        fi
    fi

    if command -v papirus-folders >/dev/null 2>&1; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            info "Would run: sudo papirus-folders -C violet -t Papirus-Dark"
        else
            sudo papirus-folders -C violet -t Papirus-Dark || warn "Failed to recolor Papirus folders"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Optional service enabling
# ---------------------------------------------------------------------------
enable_services() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        return 0
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        return 0
    fi

    local services=(sddm NetworkManager bluetooth cups firewalld)
    info "Optional: enable common system services."

    for svc in "${services[@]}"; do
        if confirm "Enable $svc.service now?"; then
            sudo systemctl enable --now "$svc" || warn "Failed to enable $svc"
        fi
    done

    # User services shipped in config/systemd/user
    if [[ -f "$HOME_CONFIG/systemd/user/auto-power-profile.service" ]]; then
        systemctl --user daemon-reload || true
        if confirm "Enable auto-power-profile.service (user) now?"; then
            systemctl --user enable --now auto-power-profile.service \
                || warn "Failed to enable auto-power-profile.service"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    info "Dotfiles installer starting."
    info "Mode: $([[ "$COPY_MODE" -eq 1 ]] && echo copy || echo symlink)"
    [[ "$DRY_RUN" -eq 1 ]] && info "DRY RUN: no changes will be made."

    install_packages
    install_configs
    install_home_files
    install_share_files
    install_local_scripts
    install_wallpapers
    install_system_files
    apply_defaults
    enable_services

    if [[ "$DRY_RUN" -eq 0 ]]; then
        success "Dotfiles installed. Log out/in or run 'hyprctl reload' to apply."
    else
        info "Dry run complete. Re-run without --dry-run to apply changes."
    fi
}

main "$@"
