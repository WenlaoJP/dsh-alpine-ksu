#!/system/bin/sh
# Secondary non-blocking start path. Some LKM/late-load configurations run
# boot-completed.sh when service.sh does not; both are safe and idempotent.
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
    "$BB" setsid "$MODDIR/bin/dsh-service-boot" >>"$DATA/logs/boot-completed.log" 2>&1 &
else
    nohup "$MODDIR/bin/dsh-service-boot" >>"$DATA/logs/boot-completed.log" 2>&1 &
fi
exit 0
