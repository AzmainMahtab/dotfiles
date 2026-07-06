# Rice backup — Catppuccin Mocha Hyprland

## Restore on a fresh Arch install

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

After changing any config, re-copy the relevant file(s) from `~/.config/`
into this repo, then `git add -A && git commit`.
