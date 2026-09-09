#!/usr/bin/env bash
# Screenshot: hyprpicker freeze -> slurp select -> grim capture -> preview,
#             and nothing is written or copied until you pick an action.
#
# Usage: screenshot.sh [smart|region|windows|fullscreen] [preview|copy|save] [--editor=NAME]
#
# Flow (default `preview`):
#   1. select a region (snaps to windows/outputs; click grabs the one under
#      the cursor)
#   2. the shot opens in satty as a preview -- annotate it or don't
#   3. choose:  Ctrl+S / toolbar save -> write to $save_dir
#               Ctrl+C / Enter        -> copy to clipboard
#               Esc                   -> discard
#      satty exits after save or copy (--early-exit all).
#
# Until step 3 the capture exists only as a temp file under XDG_RUNTIME_DIR,
# which is tmpfs (RAM) -- it never touches disk, and it is removed when the
# editor exits. `copy` and `save` skip the preview for scripted use.
#
# Waybar's layer-shell "top" layer always renders above a normal toplevel
# window -- no windowrule/hide hack can put a toplevel capture UI (flameshot)
# above it. slurp is a layer-shell client itself, so its selection overlay is
# genuinely the topmost layer: waybar stays fully visible, live, and included
# in the capture the whole time -- no hiding needed at all.
#
# hyprpicker -r -z freezes the screen behind slurp (same trick Omarchy's own
# screenshot script uses) so selection happens over a still frame instead of
# the live desktop. It is killed after grim captures but before the preview
# opens, so the frozen frame covers the capture without sitting on top of the
# editor window.
#
# Selection behaviour is ported from Omarchy's bin/omarchy-capture-screenshot;
# the preview-first handoff replaces its notification, which relied on
# left-click firing the default action. That is a mako behaviour -- dunst
# binds do_action to the MIDDLE button (mouse_left_click = close_current in
# config/dunst/dunstrc), so a left click only dismissed it.
#
# Omarchy does the geometry in jq, which is not installed here, so that logic
# lives in the _geometry() python helper below. python3 is already a dotfiles
# dependency (local/bin/auto-power-profile.py).

set -euo pipefail

# Re-pressing the bind while a selection is up cancels it (Omarchy's toggle).
pkill slurp && exit 0

save_dir="${SCREENSHOT_DIR:-$HOME/Downloads}"
editor="${SCREENSHOT_EDITOR:-satty}"

# --editor=NAME may appear in any position; everything else is positional.
args=()
for arg in "$@"; do
    case "$arg" in
        --editor=*) editor="${arg#--editor=}" ;;
        *)          args+=("$arg") ;;
    esac
done
set -- ${args[@]+"${args[@]}"}

mode="${1:-smart}"
processing="${2:-preview}"

# Monitor geometry in *logical* coords (what slurp and grim speak): raw mode
# pixels divided by scale, with width/height swapped for 90/270 rotations.
# `rects` lists the focused workspace's outputs and its mapped windows;
# `focused` lists just the focused output.
_geometry() {
    python3 - "$1" <<'PY_EOF'
import json, subprocess, sys

def hypr(what):
    out = subprocess.run(["hyprctl", "-j", what], capture_output=True, text=True)
    return json.loads(out.stdout or "[]")

def mon_geo(m):
    scale = m.get("scale") or 1
    w, h = int(m["width"] / scale), int(m["height"] / scale)
    if m.get("transform", 0) in (1, 3):
        w, h = h, w
    return f'{m["x"]},{m["y"]} {w}x{h}'

mode = sys.argv[1]
monitors = hypr("monitors")

if mode == "focused":
    for m in monitors:
        if m.get("focused"):
            print(mon_geo(m))
elif mode == "rects":
    ws = next((m["activeWorkspace"]["id"] for m in monitors if m.get("focused")), None)
    if ws is None:
        sys.exit(0)
    for m in monitors:
        if m.get("activeWorkspace", {}).get("id") == ws:
            print(mon_geo(m))
    for c in hypr("clients"):
        if c.get("workspace", {}).get("id") != ws:
            continue
        if not c.get("mapped", True) or c.get("hidden", False):
            continue
        (x, y), (w, h) = c["at"], c["size"]
        if w > 0 and h > 0:
            print(f"{x},{y} {w}x{h}")
PY_EOF
}

freeze_pid=""
tmpshot=""
_cleanup() {
    [[ -n $freeze_pid ]] && kill "$freeze_pid" 2>/dev/null
    [[ -n $tmpshot ]] && rm -f "$tmpshot"
    return 0
}
trap _cleanup EXIT
# bash does not run an EXIT trap when killed by a signal, which would strand
# the capture in tmpfs until reboot. Exiting from these handlers does.
trap 'exit 130' INT
trap 'exit 143' TERM HUP

_freeze() {
    hyprpicker -r -z >/dev/null 2>&1 &
    freeze_pid=$!
    sleep 0.1
}
# The frozen overlay must come down before the preview opens, or it sits on
# top of the editor window.
_unfreeze() {
    [[ -n $freeze_pid ]] && kill "$freeze_pid" 2>/dev/null || true
    freeze_pid=""
}

# Opens the capture for review. Neither editor is given a path it will write
# on its own: satty's --output-filename is only used by its save action, and
# swappy is deliberately called without -o (which would write on exit).
_preview() {
    local f="$1"
    case "$editor" in
        satty)
            satty --filename "$f" \
                  --output-filename "$save_dir/screenshot_%Y-%m-%d_%H-%M-%S.png" \
                  --copy-command 'wl-copy' \
                  --early-exit all \
                  --actions-on-enter save-to-clipboard \
                  --actions-on-escape exit
            ;;
        swappy) swappy -f "$f" ;;
        *)      "$editor" "$f" ;;
    esac
}

case "$mode" in
    region)
        _freeze
        selection="$(slurp 2>/dev/null || true)"
        ;;
    windows)
        rects="$(_geometry rects)"
        _freeze
        selection="$(printf '%s\n' "$rects" | slurp -r 2>/dev/null || true)"
        ;;
    fullscreen)
        selection="$(_geometry focused)"
        ;;
    smart|*)
        rects="$(_geometry rects)"
        _freeze
        selection="$(printf '%s\n' "$rects" | slurp 2>/dev/null || true)"

        # A click rather than a drag: assume the window/output under the
        # cursor was meant, instead of capturing a 2px snapshot.
        #
        # Omarchy breaks on the first containing rect, but _geometry lists
        # outputs before windows -- so an output always matches first and a
        # click can never resolve to a window. Take the smallest containing
        # rect instead, which is what its comment ("whichever window or
        # output it was inside of") actually describes: the window under the
        # cursor, falling back to the output when the click missed them all.
        if [[ $selection =~ ^([0-9-]+),([0-9-]+)[[:space:]]([0-9]+)x([0-9]+)$ ]]; then
            click_x="${BASH_REMATCH[1]}"
            click_y="${BASH_REMATCH[2]}"
            if (( BASH_REMATCH[3] * BASH_REMATCH[4] < 20 )); then
                best_area=-1
                while IFS= read -r rect; do
                    [[ $rect =~ ^([0-9-]+),([0-9-]+)[[:space:]]([0-9]+)x([0-9]+) ]] || continue
                    rx="${BASH_REMATCH[1]}"; ry="${BASH_REMATCH[2]}"
                    rw="${BASH_REMATCH[3]}"; rh="${BASH_REMATCH[4]}"
                    if (( click_x >= rx && click_x < rx + rw && click_y >= ry && click_y < ry + rh )); then
                        area=$(( rw * rh ))
                        if (( best_area < 0 || area < best_area )); then
                            best_area=$area
                            selection="$rx,$ry ${rw}x${rh}"
                        fi
                    fi
                done <<<"$rects"
            fi
        fi
        ;;
esac

[[ -z ${selection:-} ]] && exit 0

case "$processing" in
    copy)
        grim -g "$selection" - | wl-copy
        _unfreeze
        ;;
    save)
        mkdir -p "$save_dir"
        file="$save_dir/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
        grim -g "$selection" "$file"
        _unfreeze
        echo "$file"
        ;;
    preview|slurp|*)
        # tmpfs, so the capture is held in RAM rather than written to disk
        # while it waits for you to decide. Removed by the EXIT trap.
        mkdir -p "$save_dir"
        tmpshot="$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" screenshot-XXXXXX.png)"
        grim -g "$selection" "$tmpshot"
        _unfreeze
        _preview "$tmpshot"
        ;;
esac
