#!/usr/bin/env bash
# Regenerate the package lists, honouring pkglist-ignore.txt.
# Use this instead of a bare `pacman -Qqe > pkglist-explicit.txt`, which would
# silently reinstate deliberately-excluded one-off tooling.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

ignore="pkglist-ignore.txt"
[[ -f "$ignore" ]] || : > "$ignore"

pacman -Qqe | grep -vxFf "$ignore" | sort > pkglist-explicit.txt
pacman -Qqm | grep -vxFf "$ignore" | sort > pkglist-aur.txt

printf 'pkglist-explicit.txt: %s packages\n' "$(wc -l < pkglist-explicit.txt)"
printf 'pkglist-aur.txt:      %s packages\n' "$(wc -l < pkglist-aur.txt)"
printf 'excluded:             %s\n' "$(tr '\n' ' ' < "$ignore")"
