#!/system/bin/sh
# Stop the service. User data under /data/adb/dsh and /sdcard/DSH is preserved.
case "$0" in
  */*) MODDIR=${0%/*} ;;
  *)   MODDIR=$(pwd) ;;
esac
[ -x "$MODDIR/action.sh" ] && sh "$MODDIR/action.sh" stop >/dev/null 2>&1 || true
exit 0
