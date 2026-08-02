#!/usr/bin/env bash

lock=$'\U000f033e'
logout=$'\U000f0343'
restart=$'\U000f0709'
power=$'\U000f0425'

entries="$(printf '%s  Lock\n%s  Logout\n%s  Reboot\n%s  Power off' "$lock" "$logout" "$restart" "$power")"

wofi_common="--conf $HOME/.config/wofi/power-menu-config --style $HOME/.config/wofi/power-menu.css"

selected=$(printf '%s' "$entries" | wofi --dmenu $wofi_common)

confirm() {
    local action="$1"
    local choice
    choice=$(printf 'Yes\nNo' | wofi --dmenu --prompt "Confirm $action?" $wofi_common)
    [[ "$choice" == "Yes" ]]
}

case "$selected" in
    *Lock*)
        hyprlock
        ;;
    *Logout*)
        uwsm stop
        ;;
    *Reboot*)
        confirm "Reboot" && systemctl reboot
        ;;
    *"Power off"*)
        confirm "Power off" && systemctl poweroff
        ;;
esac
