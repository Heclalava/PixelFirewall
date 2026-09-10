#!/system/bin/sh

MODDIR="${0%/*}"
DATA_DIR="/data/adb/pixelfirewall"
LOGCAT="/system/bin/logcat"
SH="/system/bin/sh"

LOG="$DATA_DIR/service.log"
EVENT="$DATA_DIR/app-watch.event"
LOCK="$DATA_DIR/app-watch.lock"
DEBOUNCE=2

WORKER_PID=""

log_msg() {
    printf "[%s] %s\n" "$(date "+%Y-%m-%d %H:%M:%S")" "$1" >> "$LOG"
}

refresh_cache() {
    log_msg "Refreshing apps cache"

    if "$SH" "$MODDIR/refresh_apps" >/dev/null 2>&1; then
        log_msg "Apps cache refreshed"
    else
        log_msg "ERROR: Apps cache refresh failed"
    fi
}

cleanup() {
    [ -n "$WORKER_PID" ] && kill "$WORKER_PID" 2>/dev/null
    rm -f "$EVENT"
    rmdir "$LOCK" 2>/dev/null || true
    exit 0
}

mkdir -p "$DATA_DIR" || exit 1

if ! mkdir "$LOCK" 2>/dev/null; then
    log_msg "App watcher already running"
    exit 0
fi

trap cleanup EXIT INT TERM HUP

rm -f "$EVENT"

log_msg "App watcher started"

refresh_cache

(
    while true
    do
        if [ -f "$EVENT" ]; then
            LAST="$(cat "$EVENT" 2>/dev/null)"

            sleep "$DEBOUNCE"

            CURRENT="$(cat "$EVENT" 2>/dev/null)"

            if [ "$LAST" = "$CURRENT" ]; then
                rm -f "$EVENT"
                refresh_cache
            fi
        else
            sleep 1
        fi
    done
) &

WORKER_PID=$!

START_TIME="$(date "+%m-%d %H:%M:%S.000")"

"$LOGCAT" -v threadtime -T "$START_TIME" 2>/dev/null |
while IFS= read -r line
do
    case "$line" in
        *android.intent.action.PACKAGE_ADDED*)
            log_msg "Package event detected: PACKAGE_ADDED"
            date +%s%N > "$EVENT"
            ;;
        *android.intent.action.PACKAGE_REMOVED*)
            log_msg "Package event detected: PACKAGE_REMOVED"
            date +%s%N > "$EVENT"
            ;;
        *android.intent.action.PACKAGE_CHANGED*)
            log_msg "Package event detected: PACKAGE_CHANGED"
            date +%s%N > "$EVENT"
            ;;
        *android.intent.action.PACKAGE_REPLACED*)
            log_msg "Package event detected: PACKAGE_REPLACED"
            date +%s%N > "$EVENT"
            ;;
    esac
done
