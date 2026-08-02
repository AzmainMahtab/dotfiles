# Rice backup — Catppuccin Mocha Hyprland

## Quick install on a fresh Arch install

Run the installer from inside this repo:

```bash
./install.sh
```

By default it symlinks configs back into `~/.config` so changes in the repo are
live. Use `./install.sh --copy` if you prefer copies. Other useful flags:

```bash
./install.sh --dry-run      # preview what would be changed
./install.sh --no-packages  # skip package installation
./install.sh --no-system    # skip /etc/pam.d file changes
./install.sh --yes          # answer yes to all prompts (use with care)
```

## Manual restore on a fresh Arch install

1. Install packages:
   ```bash
   paru -S --needed - < pkglist-explicit.txt
   ```
   `pkglist-aur.txt` lists which of those came from the AUR, for reference.

2. Copy configs back into place:
   ```bash
   cp -r config/hypr config/waybar config/wofi config/dunst config/kitty ~/.config/
   cp config/gtk-3.0/settings.ini ~/.config/gtk-3.0/settings.ini
   cp config/gtk-4.0/settings.ini ~/.config/gtk-4.0/settings.ini
   cp config/mimeapps.list ~/.config/mimeapps.list
   ```

3. Scripts and wallpapers:
   ```bash
   mkdir -p ~/.local/bin
   cp local/bin/wallpaper-picker ~/.local/bin/
   chmod +x ~/.local/bin/wallpaper-picker ~/.config/waybar/scripts/network-menu.sh
   mkdir -p ~/Pictures/Wallpapers
   cp wallpapers/* ~/Pictures/Wallpapers/
   ```

4. Set defaults and recolor icons:
   ```bash
   xdg-mime default thunar.desktop inode/directory
   xdg-settings set default-web-browser firefox.desktop
   papirus-folders -C violet -t Papirus-Dark
   ```

5. Log out/in (or `hyprctl reload`) to pick everything up.

## Updating this backup

If you used the symlink installer, edits in `~/.config` are already reflected in
this repo. If you used copy mode, re-copy the relevant file(s) from `~/.config/`
into this repo, then `git add -A && git commit`.
