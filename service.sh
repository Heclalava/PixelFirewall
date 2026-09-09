#!/system/bin/sh

# PixelFirewall - firewall engine
# Phase 1: create isolated IPv4/IPv6 chain framework.
#
# IMPORTANT:
# - Never flush Android-owned chains.
# - Only manipulate PIXELFW-owned chains and hooks.
# - This phase does NOT block traffic.

MODDIR="${0%/*}"
DATA_DIR="/data/adb/pixelfirewall"
LOG_FILE="$DATA_DIR/service.log"

IPTABLES="/system/bin/iptables"
IP6TABLES="/system/bin/ip6tables"

MAIN_CHAIN="PIXELFW"
MOBILE_CHAIN="PIXELFW-MOBILE"
WIFI_CHAIN="PIXELFW-WIFI"
LAN_CHAIN="PIXELFW-LAN"

mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

chain_exists() {
    "$1" -L "$2" >/dev/null 2>&1
}

remove_all_jumps() {
    TABLE="$1"
    CHAIN="$2"

    while "$TABLE" -C OUTPUT -j "$CHAIN" >/dev/null 2>&1; do
        "$TABLE" -D OUTPUT -j "$CHAIN" >/dev/null 2>&1 || break
    done
}

create_chain() {
    TABLE="$1"
    CHAIN="$2"

    if chain_exists "$TABLE" "$CHAIN"; then
        "$TABLE" -F "$CHAIN" || return 1
    else
        "$TABLE" -N "$CHAIN" || return 1
    fi

    return 0
}

setup_ipv4() {
    log_msg "Setting up IPv4 chains"

    remove_all_jumps "$IPTABLES" "$MAIN_CHAIN"

    create_chain "$IPTABLES" "$MAIN_CHAIN" || return 1
    create_chain "$IPTABLES" "$MOBILE_CHAIN" || return 1
    create_chain "$IPTABLES" "$WIFI_CHAIN" || return 1
    create_chain "$IPTABLES" "$LAN_CHAIN" || return 1

    # Phase 1: no blocking. Explicit RETURN keeps the chains fail-open.
    "$IPTABLES" -A "$MOBILE_CHAIN" -j RETURN
    "$IPTABLES" -A "$WIFI_CHAIN" -j RETURN
    "$IPTABLES" -A "$LAN_CHAIN" -j RETURN
    "$IPTABLES" -A "$MAIN_CHAIN" -j RETURN

    "$IPTABLES" -I OUTPUT 1 -j "$MAIN_CHAIN" || return 1

    return 0
}

setup_ipv6() {
    log_msg "Setting up IPv6 chains"

    remove_all_jumps "$IP6TABLES" "$MAIN_CHAIN"

    create_chain "$IP6TABLES" "$MAIN_CHAIN" || return 1
    create_chain "$IP6TABLES" "$MOBILE_CHAIN" || return 1
    create_chain "$IP6TABLES" "$WIFI_CHAIN" || return 1
    create_chain "$IP6TABLES" "$LAN_CHAIN" || return 1

    # Phase 1: no blocking. Explicit RETURN keeps the chains fail-open.
    "$IP6TABLES" -A "$MOBILE_CHAIN" -j RETURN
    "$IP6TABLES" -A "$WIFI_CHAIN" -j RETURN
    "$IP6TABLES" -A "$LAN_CHAIN" -j RETURN
    "$IP6TABLES" -A "$MAIN_CHAIN" -j RETURN

    "$IP6TABLES" -I OUTPUT 1 -j "$MAIN_CHAIN" || return 1

    return 0
}

log_msg "=== PixelFirewall Activated ==="

# Give Android a moment to finish bringing up the firewall tables after boot.
sleep 10

if setup_ipv4; then
    log_msg "IPv4 firewall framework initialized"
else
    log_msg "ERROR: IPv4 firewall framework initialization failed"
fi

if setup_ipv6; then
    log_msg "IPv6 firewall framework initialized"
else
    log_msg "ERROR: IPv6 firewall framework initialization failed"
fi

log_msg "=== PixelFirewall Ready (Phase 1, fail-open) ==="

# Keep the service alive for Magisk's service process.
# Rule recovery will be implemented in a later phase.
while true; do
    sleep 300
done
