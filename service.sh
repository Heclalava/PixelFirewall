#!/system/bin/sh

MODDIR="${0%/*}"
DATA_DIR="/data/adb/pixelfirewall"
LOG_FILE="$DATA_DIR/service.log"
STATE_FILE="$DATA_DIR/network.state"

IPTABLES="/system/bin/iptables"
IP6TABLES="/system/bin/ip6tables"
IP="/system/bin/ip"

MAIN_CHAIN="PIXELFW"
MOBILE_CHAIN="PIXELFW-MOBILE"
WIFI_CHAIN="PIXELFW-WIFI"
LAN_CHAIN="PIXELFW-LAN"

POLL_INTERVAL=30

umask 077

mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

log_msg() {
    echo "[$(/system/bin/date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
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

setup_base_ipv4() {
    remove_all_jumps "$IPTABLES" "$MAIN_CHAIN"

    create_chain "$IPTABLES" "$MAIN_CHAIN" || return 1
    create_chain "$IPTABLES" "$MOBILE_CHAIN" || return 1
    create_chain "$IPTABLES" "$WIFI_CHAIN" || return 1
    create_chain "$IPTABLES" "$LAN_CHAIN" || return 1

    "$IPTABLES" -A "$MOBILE_CHAIN" -j RETURN || return 1
    "$IPTABLES" -A "$WIFI_CHAIN" -j RETURN || return 1
    "$IPTABLES" -A "$LAN_CHAIN" -j RETURN || return 1
    "$IPTABLES" -A "$MAIN_CHAIN" -j RETURN || return 1

    "$IPTABLES" -I OUTPUT 1 -j "$MAIN_CHAIN" || return 1

    return 0
}

setup_base_ipv6() {
    remove_all_jumps "$IP6TABLES" "$MAIN_CHAIN"

    create_chain "$IP6TABLES" "$MAIN_CHAIN" || return 1
    create_chain "$IP6TABLES" "$MOBILE_CHAIN" || return 1
    create_chain "$IP6TABLES" "$WIFI_CHAIN" || return 1
    create_chain "$IP6TABLES" "$LAN_CHAIN" || return 1

    "$IP6TABLES" -A "$MOBILE_CHAIN" -j RETURN || return 1
    "$IP6TABLES" -A "$WIFI_CHAIN" -j RETURN || return 1
    "$IP6TABLES" -A "$LAN_CHAIN" -j RETURN || return 1
    "$IP6TABLES" -A "$MAIN_CHAIN" -j RETURN || return 1

    "$IP6TABLES" -I OUTPUT 1 -j "$MAIN_CHAIN" || return 1

    return 0
}

normalize_ipv6_64() {
    ADDR="$1"

    ADDR="${ADDR%%/*}"

    echo "$ADDR" | awk -F: '

    {
        left=$0
        right=""

        if (index($0,"::") > 0) {
            split($0,a,"::")
            left=a[1]
            right=a[2]

            ln=0
            rn=0

            if (left != "")
                ln=split(left,l,":")

            if (right != "")
                rn=split(right,r,":")

            missing=8-ln-rn

            n=0

            for (i=1;i<=ln;i++) {
                if (n < 4) {
                    if (l[i] == "") l[i]="0"
                    printf "%s%s", l[i], (n < 3 ? ":" : "")
                    n++
                }
            }

            while (n < 4 && missing > 0) {
                printf "%s%s", "0", (n < 3 ? ":" : "")
                n++
                missing--
            }

            for (i=1;i<=rn && n<4;i++) {
                printf "%s%s", r[i], (n < 3 ? ":" : "")
                n++
            }

            print "::/64"
        } else {
            split($0,h,":")
            printf "%s:%s:%s:%s::/64\n", h[1],h[2],h[3],h[4]
        }
    }'
}

build_network_state() {
    {
        WLAN_UP=$("$IP" -o link show up 2>/dev/null | awk -F': ' '$2=="wlan0" {print "yes"}')

        if [ "$WLAN_UP" = "yes" ]; then
            WLAN4_FOUND=$("$IP" -4 route show dev wlan0 proto kernel scope link 2>/dev/null | awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$/ {print $1; exit}')

            if [ -n "$WLAN4_FOUND" ]; then
                printf 'WLAN4|%s\n' "$WLAN4_FOUND"
            else
                "$IP" -4 -o addr show dev wlan0 scope global 2>/dev/null |
                    awk '
                    function network(ip, prefix,    a,n,bits,mask,i,out) {
                        split(ip,a,".")
                        n=prefix
                        out=""

                        for (i=1;i<=4;i++) {
                            if (n >= 8) {
                                b=a[i]
                                n-=8
                            } else if (n > 0) {
                                mask=256-(2^(8-n))
                                b=int(a[i]/mask)*mask
                                n=0
                            } else {
                                b=0
                            }

                            out=out (i > 1 ? "." : "") b
                        }

                        return out "/" prefix
                    }

                    $4 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$/ {
                        split($4,a,"/")
                        print "WLAN4|" network(a[1],a[2])
                        exit
                    }'
            fi

            "$IP" -6 -o addr show dev wlan0 scope global 2>/dev/null |
                awk '{print $4}' |
                while read -r ADDR; do
                    case "$ADDR" in
                        */64)
                            PREFIX=$(normalize_ipv6_64 "$ADDR")
                            [ -n "$PREFIX" ] && printf 'WLAN6|%s\n' "$PREFIX"
                            ;;
                    esac
                done
        fi

        "$IP" -o link show up 2>/dev/null |
            awk -F': ' '$2 ~ /^rmnet[0-9]+$/ {print "MOBILE|" $2}'
    } | sort -u
}

restore_fail_open() {
    "$IPTABLES" -F "$MAIN_CHAIN" >/dev/null 2>&1
    "$IPTABLES" -F "$MOBILE_CHAIN" >/dev/null 2>&1
    "$IPTABLES" -F "$WIFI_CHAIN" >/dev/null 2>&1
    "$IPTABLES" -F "$LAN_CHAIN" >/dev/null 2>&1

    "$IP6TABLES" -F "$MAIN_CHAIN" >/dev/null 2>&1
    "$IP6TABLES" -F "$MOBILE_CHAIN" >/dev/null 2>&1
    "$IP6TABLES" -F "$WIFI_CHAIN" >/dev/null 2>&1
    "$IP6TABLES" -F "$LAN_CHAIN" >/dev/null 2>&1

    "$IPTABLES" -A "$MAIN_CHAIN" -j RETURN >/dev/null 2>&1
    "$IP6TABLES" -A "$MAIN_CHAIN" -j RETURN >/dev/null 2>&1
    "$IPTABLES" -A "$MOBILE_CHAIN" -j RETURN >/dev/null 2>&1
    "$IPTABLES" -A "$WIFI_CHAIN" -j RETURN >/dev/null 2>&1
    "$IPTABLES" -A "$LAN_CHAIN" -j RETURN >/dev/null 2>&1
    "$IP6TABLES" -A "$MOBILE_CHAIN" -j RETURN >/dev/null 2>&1
    "$IP6TABLES" -A "$WIFI_CHAIN" -j RETURN >/dev/null 2>&1
    "$IP6TABLES" -A "$LAN_CHAIN" -j RETURN >/dev/null 2>&1
}

rebuild_dispatcher() {
    NEW_STATE="$1"

    "$IPTABLES" -F "$MAIN_CHAIN" || return 1
    "$IPTABLES" -F "$MOBILE_CHAIN" || return 1
    "$IPTABLES" -F "$WIFI_CHAIN" || return 1
    "$IPTABLES" -F "$LAN_CHAIN" || return 1

    "$IP6TABLES" -F "$MAIN_CHAIN" || return 1
    "$IP6TABLES" -F "$MOBILE_CHAIN" || return 1
    "$IP6TABLES" -F "$WIFI_CHAIN" || return 1
    "$IP6TABLES" -F "$LAN_CHAIN" || return 1

    while IFS='|' read -r TYPE VALUE; do
        case "$TYPE" in
            MOBILE)
                "$IPTABLES" -A "$MAIN_CHAIN" -o "$VALUE" -j "$MOBILE_CHAIN" || return 1
                "$IP6TABLES" -A "$MAIN_CHAIN" -o "$VALUE" -j "$MOBILE_CHAIN" || return 1
                ;;
            WLAN4)
                "$IPTABLES" -A "$MAIN_CHAIN" -o wlan0 -d "$VALUE" -j "$LAN_CHAIN" || return 1
                ;;
            WLAN6)
                "$IP6TABLES" -A "$MAIN_CHAIN" -o wlan0 -d "$VALUE" -j "$LAN_CHAIN" || return 1
                ;;
        esac
    done < "$NEW_STATE"

    if grep -q '^WLAN4|' "$NEW_STATE"; then
        "$IPTABLES" -A "$MAIN_CHAIN" -o wlan0 -j "$WIFI_CHAIN" || return 1
    fi

    if grep -q '^WLAN6|' "$NEW_STATE"; then
        "$IP6TABLES" -A "$MAIN_CHAIN" -o wlan0 -j "$WIFI_CHAIN" || return 1
    fi

    "$IPTABLES" -A "$MAIN_CHAIN" -j RETURN || return 1
    "$IP6TABLES" -A "$MAIN_CHAIN" -j RETURN || return 1

    "$IPTABLES" -A "$MOBILE_CHAIN" -j RETURN || return 1
    "$IPTABLES" -A "$WIFI_CHAIN" -j RETURN || return 1
    "$IPTABLES" -A "$LAN_CHAIN" -j RETURN || return 1

    "$IP6TABLES" -A "$MOBILE_CHAIN" -j RETURN || return 1
    "$IP6TABLES" -A "$WIFI_CHAIN" -j RETURN || return 1
    "$IP6TABLES" -A "$LAN_CHAIN" -j RETURN || return 1

    return 0
}

apply_dispatcher() {
    TMP_STATE="$DATA_DIR/network.state.tmp.$$"

    build_network_state > "$TMP_STATE"

    if [ -f "$STATE_FILE" ] && cmp -s "$TMP_STATE" "$STATE_FILE"; then
        rm -f "$TMP_STATE"
        return 0
    fi

    if rebuild_dispatcher "$TMP_STATE"; then
        mv -f "$TMP_STATE" "$STATE_FILE"
        log_msg "Network dispatcher updated"
        return 0
    fi

    rm -f "$TMP_STATE"
    restore_fail_open
    log_msg "ERROR: Network dispatcher rebuild failed; fail-open restored"
    return 1
}

log_msg "=== PixelFirewall Activated ==="

sleep 10

if setup_base_ipv4; then
    log_msg "IPv4 firewall framework initialized"
else
    log_msg "ERROR: IPv4 firewall framework initialization failed"
fi

if setup_base_ipv6; then
    log_msg "IPv6 firewall framework initialized"
else
    log_msg "ERROR: IPv6 firewall framework initialization failed"
fi

rm -f "$STATE_FILE"

if apply_dispatcher; then
    log_msg "Network dispatcher initialized"
else
    log_msg "ERROR: Network dispatcher initialization failed"
fi

log_msg "=== PixelFirewall Ready (Phase 2, fail-open) ==="

while true; do
    sleep "$POLL_INTERVAL"
    apply_dispatcher
done
