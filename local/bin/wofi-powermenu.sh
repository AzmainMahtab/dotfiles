#!/usr/bin/env bash

lock=$'\U000f033e'
logout=$'\U000f0343'
restart=$'\U000f0709'
power=$'\U000f0425'

entries="$(printf '%s  Lock\n%s  Logout\n%s  Reboot\n%s  Power off' "$lock" "$logout" "$restart" "$power")"

selected=$(printf '%s' "$entries" | wofi --dmenu --conf ~/.config/wofi/power-menu-config --style ~/.config/wofi/power-menu-style.css)

case "$selected" in
    *Lock*)
        hyprlock
        ;;
    *Logout*)
        uwsm stop
        ;;
    *Reboot*)
        systemctl reboot
        ;;
    *"Power off"*)
        systemctl poweroff
        ;;
esac
