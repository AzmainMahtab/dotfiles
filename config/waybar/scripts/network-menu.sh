#!/usr/bin/env bash
# Wi-Fi dropdown menu for waybar, replacing nm-applet's tray menu.

set -u

wofi_menu() {
    wofi --dmenu -p "Network" --width 340 --lines 10
}

radio_state=$(nmcli -g WIFI radio)

build_menu() {
    if [ "$radio_state" = "enabled" ]; then
        echo "󰖪  Disable Wi-Fi"
    else
        echo "󰖩  Enable Wi-Fi"
    fi
    echo "󰒓  Open Connection Editor"
    echo "---"

    if [ "$radio_state" = "enabled" ]; then
        nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list \
            | awk -F: '!seen[$4]++' \
            | sort -t: -k2 -rn \
            | while IFS=: read -r inuse signal security ssid; do
                [ -z "$ssid" ] && continue
                mark="  "
                [ "$inuse" = "*" ] && mark="󰸞 "
                lock=""
                [ -n "$security" ] && lock=" 󰌾"
                echo "${mark}${ssid} (${signal}%)${lock}"
            done
    fi
}

choice=$(build_menu | wofi_menu)
[ -z "$choice" ] && exit 0

case "$choice" in
    *"Disable Wi-Fi")
        nmcli radio wifi off
        notify-send -a "Network" "Wi-Fi disabled"
        exit 0
        ;;
    *"Enable Wi-Fi")
        nmcli radio wifi on
        notify-send -a "Network" "Wi-Fi enabled"
        exit 0
        ;;
    *"Open Connection Editor")
        exec nm-connection-editor
        ;;
esac

ssid=$(echo "$choice" | sed -E 's/^[^ ]+ //; s/ \([0-9]+%\)( 󰌾)?$//')

if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
    if nmcli connection up "$ssid" >/tmp/nmconnect.log 2>&1; then
        notify-send -a "Network" "Connected to $ssid"
    else
        notify-send -a "Network" "Failed to connect to $ssid" "$(cat /tmp/nmconnect.log)"
    fi
    exit 0
fi

secured=$(echo "$choice" | grep -q '󰌾' && echo yes || echo no)

if [ "$secured" = "yes" ]; then
    password=$(echo "" | wofi --dmenu -p "Password for $ssid" --password)
    [ -z "$password" ] && exit 0
    if nmcli device wifi connect "$ssid" password "$password" >/tmp/nmconnect.log 2>&1; then
        notify-send -a "Network" "Connected to $ssid"
    else
        notify-send -a "Network" "Failed to connect to $ssid" "$(cat /tmp/nmconnect.log)"
    fi
else
    if nmcli device wifi connect "$ssid" >/tmp/nmconnect.log 2>&1; then
        notify-send -a "Network" "Connected to $ssid"
    else
        notify-send -a "Network" "Failed to connect to $ssid" "$(cat /tmp/nmconnect.log)"
    fi
fi
