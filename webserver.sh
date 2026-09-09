#!/system/bin/sh
MODDIR="${0%/*}"
DATA_DIR="/data/adb/pixelfirewall"
HTTPD="/data/adb/magisk/busybox httpd"
PORT=8765
PIDFILE="$DATA_DIR/httpd.pid"
LOGFILE="$DATA_DIR/httpd.log"
mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then exit 0; fi
rm -f "$PIDFILE"
cd "$MODDIR/webroot" || exit 1
$HTTPD -p 127.0.0.1:$PORT -h "$MODDIR/webroot" >"$LOGFILE" 2>&1 &
PID=$!
echo "$PID" > "$PIDFILE"
chmod 600 "$PIDFILE"
exit 0
