#!/system/bin/sh
MODDIR="${0%/*}"
DATA_DIR="/data/adb/pixelfirewall"
HTTPD="/data/adb/magisk/busybox"
PORT=8765
PIDFILE="$DATA_DIR/httpd.pid"
LOGFILE="$DATA_DIR/httpd.log"

mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

if "$HTTPD" netstat -lnt 2>/dev/null | /system/bin/grep -q "127.0.0.1:$PORT "; then
    exit 0
fi

rm -f "$PIDFILE"

cd "$MODDIR" || exit 1

"$HTTPD" httpd -p 127.0.0.1:$PORT -h "$MODDIR" -c "$MODDIR/httpd.conf" >"$LOGFILE" 2>&1 &

sleep 1

if "$HTTPD" netstat -lnt 2>/dev/null | /system/bin/grep -q "127.0.0.1:$PORT "; then
    PID=$("$HTTPD" ps 2>/dev/null | /system/bin/grep "httpd -p 127.0.0.1:$PORT" | /system/bin/grep -v grep | /system/bin/awk "{print \$1}" | /system/bin/head -1)
    [ -n "$PID" ] && echo "$PID" > "$PIDFILE"
    chmod 600 "$PIDFILE"
    exit 0
fi

rm -f "$PIDFILE"
exit 1
