#!/usr/bin/env python3
"""
Automatically switch power profile based on AC/battery state.
- On battery -> power-saver
- On AC     -> balanced

Polls /sys/class/power_supply/AC/online as a regular user (no root needed).
WiFi power save is intentionally left unchanged to preserve WiFi performance.
"""

import subprocess
import sys
import time

# Settings
AC_PATH = "/sys/class/power_supply/AC/online"
PROFILE_ON_BATTERY = "power-saver"
PROFILE_ON_AC = "balanced"
POLL_INTERVAL = 2  # seconds


def read_ac_online() -> bool:
    try:
        with open(AC_PATH, "r") as f:
            return f.read().strip() == "1"
    except OSError as e:
        print(f"Failed to read {AC_PATH}: {e}", file=sys.stderr)
        return False


def set_profile(profile: str):
    try:
        subprocess.run(
            ["powerprofilesctl", "set", profile],
            check=True,
            capture_output=True,
            text=True,
        )
        print(f"Switched to '{profile}' profile")
    except subprocess.CalledProcessError as e:
        print(f"Failed to set profile '{profile}': {e.stderr}", file=sys.stderr)


def apply_profile(ac_online: bool):
    if ac_online:
        set_profile(PROFILE_ON_AC)
    else:
        set_profile(PROFILE_ON_BATTERY)


def main():
    last_ac = None
    print("Watching AC/battery state...")

    while True:
        ac_online = read_ac_online()

        if ac_online != last_ac:
            apply_profile(ac_online)
            last_ac = ac_online

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("Interrupted, exiting.")
        sys.exit(0)
