#!/system/bin/sh
# Runs in the global mount namespace after a hot install. Return within 30s:
# stop the old instance, then start the new one in the background.
case "$0" in
  */*) MODDIR=${0%/*} ;;
  *)   MODDIR=$(pwd) ;;
esac
DATA=/data/adb/dsh
mkdir -p "$DATA/logs"
[ -x "$MODDIR/action.sh" ] && sh "$MODDIR/action.sh" stop >/dev/null 2>&1 || true
if command -v setsid >/dev/null 2>&1; then
    setsid "$MODDIR/bin/dsh-bootstrap" >>"$DATA/logs/hotinstall.log" 2>&1 &
else
    nohup "$MODDIR/bin/dsh-bootstrap" >>"$DATA/logs/hotinstall.log" 2>&1 &
fi
exit 0
