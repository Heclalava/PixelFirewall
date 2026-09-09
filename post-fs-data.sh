#!/system/bin/sh
MODDIR="${0%/*}"
/system/bin/sh "$MODDIR/webserver-start.sh" >/dev/null 2>&1 &
