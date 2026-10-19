#!/system/bin/sh
# KernelSU LKM late-load / old-manager fallback.
# IMPORTANT: never run a long-lived loop in service.sh itself; some managers
# wait for this script, which would block boot at the boot animation.
case "$0" in
  */*) MODDIR=${0%/*} ;;
  *)   MODDIR=$(pwd) ;;
esac
DATA=/data/adb/dsh
mkdir -p "$DATA/logs"

if [ -x /data/adb/ksu/bin/busybox ]; then
    BB=/data/adb/ksu/bin/busybox
elif command -v busybox >/dev/null 2>&1; then
    BB="$(command -v busybox)"
else
    BB=""
fi

if [ -n "$BB" ] && "$BB" setsid true >/dev/null 2>&1; then
    "$BB" setsid "$MODDIR/bin/dsh-service-boot" >>"$DATA/logs/service.log" 2>&1 &
else
    nohup "$MODDIR/bin/dsh-service-boot" >>"$DATA/logs/service.log" 2>&1 &
fi

# Return immediately so KernelSU can continue the boot process.
exit 0
