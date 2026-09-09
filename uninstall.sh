#!/system/bin/sh

IPTABLES="/system/bin/iptables"
IP6TABLES="/system/bin/ip6tables"

MAIN_CHAIN="PIXELFW"
MOBILE_CHAIN="PIXELFW-MOBILE"
WIFI_CHAIN="PIXELFW-WIFI"
LAN_CHAIN="PIXELFW-LAN"

remove_chain() {
    TABLE="$1"
    CHAIN="$2"

    while "$TABLE" -C OUTPUT -j "$CHAIN" >/dev/null 2>&1; do
        "$TABLE" -D OUTPUT -j "$CHAIN" >/dev/null 2>&1 || break
    done

    "$TABLE" -F "$CHAIN" >/dev/null 2>&1
    "$TABLE" -X "$CHAIN" >/dev/null 2>&1
}

remove_firewall() {
    TABLE="$1"

    remove_chain "$TABLE" "$MAIN_CHAIN"
    remove_chain "$TABLE" "$MOBILE_CHAIN"
    remove_chain "$TABLE" "$WIFI_CHAIN"
    remove_chain "$TABLE" "$LAN_CHAIN"
}

remove_firewall "$IPTABLES"
remove_firewall "$IP6TABLES"

rm -rf /data/adb/pixelfirewall

exit 0
