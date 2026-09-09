#!/system/bin/sh
MODDIR="${0%/*}"
sleep 15
/system/bin/sh "$MODDIR/webserver.sh" >/dev/null 2>&1
exit 0
