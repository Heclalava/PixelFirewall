#!/system/bin/sh

MODDIR="${0%/*}"
DATA_DIR="/data/adb/pixelfirewall"
INSTALL_LOG="$DATA_DIR/installation.log"

mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$INSTALL_LOG"
}

MODNAME=$(grep_prop name "$TMPDIR/module.prop")
MODVER=$(grep_prop version "$TMPDIR/module.prop")
AUTHOR=$(grep_prop author "$TMPDIR/module.prop")

BRAND=$(getprop ro.product.brand)
MODEL=$(getprop ro.product.model)
ANDROID=$(getprop ro.system.build.version.release)
SDK=$(getprop ro.build.version.sdk)
ARCH=$(getprop ro.product.cpu.abi)
SE=$(getenforce)

log_msg "========================================="
log_msg "          PixelFirewall Installer"
log_msg "========================================="
log_msg "Module Name    : $MODNAME"
log_msg "Version        : $MODVER"
log_msg "Author         : $AUTHOR"
log_msg "Device         : $BRAND $MODEL"
log_msg "Android        : $ANDROID (SDK $SDK)"
log_msg "Architecture   : $ARCH"
log_msg "SELinux        : $SE"
log_msg "Module Path    : $MODDIR"
log_msg "Data Path      : $DATA_DIR"
log_msg "========================================="



if [ -f "$MODDIR/uninstall.sh" ]; then
    chmod 755 "$MODDIR/uninstall.sh"
fi

chmod 755 "$MODDIR/policy-watch.sh" "$MODDIR/policy-watch.sh-handler"

touch "$DATA_DIR/blocked_uids.txt"
chmod 600 "$DATA_DIR/blocked_uids.txt"

log_msg "PixelFirewall installation files verified"
log_msg "Installation completed"
exit 0
