#!/usr/bin/env bash
# Screenshot: hyprpicker freeze -> slurp select -> grim capture -> clipboard
#             -> optional annotation in satty/swappy.
#
# Usage: screenshot.sh [smart|region|windows|fullscreen] [slurp|copy|save] [--editor=NAME]
#
# Waybar's layer-shell "top" layer always renders above a normal toplevel
# window -- no windowrule/hide hack can put a toplevel capture UI (flameshot)
# above it. slurp is a layer-shell client itself, so its selection overlay is
# genuinely the topmost layer: waybar stays fully visible, live, and included
# in the capture the whole time -- no hiding needed at all.
#
# hyprpicker -r -z freezes the screen behind slurp (same trick Omarchy's own
# screenshot script uses) so selection happens over a still frame instead of
# the live desktop. It's kept alive until after grim captures, then killed,
# so the frozen frame covers the actual capture too, not just the drag.
#
# Ported from Omarchy's bin/omarchy-capture-screenshot:
#   - re-pressing the bind cancels an in-flight selection instead of stacking
#     a second slurp
#   - slurp is fed monitor + window rectangles so selection snaps to them
#   - a click (area < 20px^2) captures the window/output under the cursor
#     rather than a 2px sliver
#   - monitor geometry is divided by scale and swapped on transform 1/3, so
#     fullscreen mode is correct on this 1.25-scaled and on rotated outputs
#   - the editor is opt-in: the shot is saved and copied immediately, and the
#     annotator only opens if you click the notification
#
# Omarchy does the geometry in jq; jq is not installed here, so the same logic
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
processing="${2:-slurp}"

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
_freeze() {
    hyprpicker -r -z >/dev/null 2>&1 &
    freeze_pid=$!
    trap '[[ -n $freeze_pid ]] && kill "$freeze_pid" 2>/dev/null' EXIT
    sleep 0.1
}
_unfreeze() {
    [[ -n $freeze_pid ]] && kill "$freeze_pid" 2>/dev/null || true
    freeze_pid=""
    trap - EXIT
}

_open_editor() {
    local f="$1"
    case "$editor" in
        satty)
            satty --filename "$f" \
                  --output-filename "$f" \
                  --actions-on-enter save-to-clipboard \
                  --save-after-copy \
                  --copy-command 'wl-copy'
            ;;
        swappy) swappy -f "$f" -o "$f" ;;
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

mkdir -p "$save_dir"
file="$save_dir/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

case "$processing" in
    copy)
        grim -g "$selection" - | wl-copy
        _unfreeze
        ;;
    save)
        grim -g "$selection" "$file"
        _unfreeze
        echo "$file"
        ;;
    slurp|*)
        grim -g "$selection" "$file"
        _unfreeze
        echo "$file"
        wl-copy <"$file"

        # notify-send -A implies --wait, so this has to be backgrounded or the
        # script would block on the notification timeout.
        (
            action="$(notify-send "Screenshot saved to clipboard and file" \
                "Click to annotate in $editor" \
                -t 10000 -i "$file" -A "default=edit")"
            [[ $action == "default" ]] && _open_editor "$file"
        ) >/dev/null 2>&1 &
        ;;
esac
