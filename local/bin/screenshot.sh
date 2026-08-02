#!/usr/bin/env bash
# Waybar's layer-shell "top" layer always renders above a normal toplevel
# window -- no windowrule/hide hack can put flameshot above it. slurp is a
# layer-shell client itself, so its selection overlay is genuinely the
# topmost layer: waybar stays fully visible, live, and included in the
# capture the whole time -- no hiding needed at all.
#
# hyprpicker -r -z freezes the screen behind slurp (same trick Omarchy's own
# screenshot script uses) so selection happens over a still frame instead of
# the live desktop. It's kept alive until after grim captures, then killed,
# so the frozen frame covers the actual capture too, not just the drag.
#
# swappy opens the saved file for annotation (brush, text, rectangle, ellipse,
# arrow, blur -- flameshot-style toolbar). Ctrl+C copies to clipboard; -o
# writes the final annotated surface back to the same file on exit either
# way -- matching the save+copy flow flameshot had.

set -euo pipefail

save_dir="$HOME/Downloads"
mkdir -p "$save_dir"
file="$save_dir/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

hyprpicker -r -z >/dev/null 2>&1 &
freeze_pid=$!
trap 'kill "$freeze_pid" 2>/dev/null' EXIT

sleep 0.1
region="$(slurp)" || exit 0
grim -g "$region" "$file"

kill "$freeze_pid" 2>/dev/null
trap - EXIT

swappy -f "$file" -o "$file"
