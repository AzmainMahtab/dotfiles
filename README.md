# Rice backup — Catppuccin Mocha Hyprland

Full replica of the Hyprland desktop: compositor, bar, launcher, notifications,
terminal, GTK/SDDM theming, fonts, shell, and the packages behind them.

## Repo layout

| Directory | Installs to | Contents |
|---|---|---|
| `config/` | `~/.config/<name>` | hypr, waybar, wofi, dunst, kitty, themes, gtk-3.0, gtk-4.0, fontconfig, nvim, systemd, mimeapps.list |
| `home/` | `~/.<name>` | bashrc, bash_profile, profile, inputrc, gitconfig — stored without the leading dot |
| `local/bin/` | `~/.local/bin/` | wallpaper-picker, wofi-powermenu.sh, screenshot.sh, open-file-manager, validate-keybind-commands, auto-power-profile.py, theme-apply, theme-select |
| `share/applications/` | `~/.local/share/applications/` | custom `.desktop` entries referenced by `mimeapps.list` |
| `system/` | `/etc/` | `pam-sudo`, `pam-hyprlock` → `/etc/pam.d/`; `sddm-theme.conf` → `/etc/sddm.conf.d/theme.conf` |
| `wallpapers/` | `~/Pictures/Wallpapers/` | wallpapers referenced by hyprpaper and the picker |
| `pkglist-*.txt` | — | rice, AUR and optional package lists |

## Quick install on a fresh Arch install

```bash
./install.sh
```

By default it **symlinks** configs back into place, so later edits are live in
this repo with no drift. Use `--copy` for independent copies. Other flags:

```bash
./install.sh --dry-run      # preview what would be changed
./install.sh --no-packages  # skip package installation
./install.sh --no-system    # skip /etc changes (PAM, SDDM theme)
./install.sh --extras       # also install pkglist-optional.txt
./install.sh --yes          # answer yes to all prompts (use with care)
```

The installer also sets desktop defaults (nemo as file manager, Brave as
browser, Bibata cursor via gsettings, Papirus folder recolour) and offers to
enable `sddm`, `NetworkManager`, `bluetooth`, `cups`, `firewalld` and the
`auto-power-profile` user service.

## Themes

`SUPER+T` opens a wofi menu with the available themes (Catppuccin, Gruvbox).
Picking one re-renders every themed app and reloads what is running.

| Piece | Location |
|---|---|
| Palettes (`key=#hex`) | `config/themes/palettes/<theme>.conf` |
| Templates (`{{key}}`, `{{key.hex}}`, `{{key.rgb}}`) | `config/themes/templates/` |
| Renderer | `local/bin/theme-apply <theme>` (`--list` shows themes) |
| Menu | `local/bin/theme-select` |
| Generated output (untracked) | `~/.config/theme-active/` |

Themed: Hyprland borders, waybar, wofi, dunst, kitty, hyprlock and nvim
(nvim picks it up on next start). GTK apps and cursors stay Catppuccin.

To add a theme, copy a palette file, change the colours and `name=`, and it
shows up in the menu. Edit templates, not the files in `theme-active/`.

## Package lists

| File | Contents |
|---|---|
| `pkglist-explicit.txt` | Rice packages only: compositor, bar, launcher, screenshots, theming, fonts, file manager, compression. Hand-curated, grouped with `#` comments. |
| `pkglist-aur.txt` | The AUR subset of the above (used by the plain-`pacman` fallback). |
| `pkglist-optional.txt` | Extras that are not part of the rice. Installed only with `./install.sh --extras`. |

Check the rice list against the live system with `./update-pkglists.sh`; it
only reports differences and never rewrites the lists.

## Not captured

A few things are intentionally left out and must be redone by hand:

- Fingerprint enrolment (`fprintd-enroll`) — `system/pam-sudo` references
  `pam_fprintd.so`, but enrolled prints are per-machine.
- Anything in `~/.local/bin` installed by another tool's installer
  (`claude`, `uv`, `pen`, `graphify`, …) — reinstall those from source.
- Browser profiles, GPG keys, SSH keys.

## Updating this backup

If installed via symlink, edits under `~/.config` are already live here — just
`git add -A && git commit`. If the files are real copies (as on a machine that
predates the installer), copy the changed file back into the matching tier
first. Re-running `./install.sh` converts copies into symlinks and ends the
drift.
