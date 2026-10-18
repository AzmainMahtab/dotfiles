#!/usr/bin/env bash
# Compare the hand-curated rice package list with the live system.
# Never rewrites the lists; edit pkglist-explicit.txt / pkglist-optional.txt by hand.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

names() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' | sort -u; }

rice=$(names pkglist-explicit.txt)
extras=$(names pkglist-optional.txt)
installed=$(pacman -Qq | sort -u)

echo "Rice packages not installed:"
comm -23 <(echo "$rice") <(echo "$installed") | sed 's/^/  /'
echo
echo "Explicitly installed, in neither list (add to rice or optional, or ignore):"
comm -23 <(pacman -Qqe | sort -u) <(sort -u <(echo "$rice") <(echo "$extras")) | sed 's/^/  /'
