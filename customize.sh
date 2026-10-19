#!/system/bin/sh
# Fast installer: never expand the ~800MB runtime in the KernelSU installer.
# The module ZIP is unpacked by the manager; first boot extracts the Alpine
# rootfs and DSH baseline in the background via bin/dsh-bootstrap.
MODPATH=${MODPATH:-${0%/*}}
DATA=/data/adb/dsh
PAYLOAD="$MODPATH/payload"

ui_print "DSH Alpine Terminal 安装"

[ "$(uname -m)" = "aarch64" ] || abort "Only arm64/aarch64 is supported"
API="$(getprop ro.build.version.sdk 2>/dev/null || echo 0)"
[ "$API" -ge 29 ] 2>/dev/null || abort "Android 10+ is required (found API $API)"

[ -f "$PAYLOAD/rootfs.tar.gz" ] || abort "payload/rootfs.tar.gz missing"
[ -f "$PAYLOAD/dsh-baseline.tar.gz" ] || abort "payload/dsh-baseline.tar.gz missing"

AVAIL="$(df -k /data 2>/dev/null | tail -1 | awk '{print $4}')"
[ -n "$AVAIL" ] || AVAIL=0
if [ "$AVAIL" -lt 3145728 ] 2>/dev/null; then
    abort "Need at least 3 GiB free on /data (found $((AVAIL/1024)) MiB)"
fi

# Only create paths and set top-level ownership. No recursive chown, no tar.
mkdir -p "$DATA" "$DATA/opt/dsh" "$DATA/home" "$DATA/logs" "$DATA/run" \
         "$DATA/state" "$DATA/npm-global" "$DATA/npm-cache" "$DATA/pnpm-store"
mkdir -p /storage/emulated/0/DSH/workspace /storage/emulated/0/DSH/npm 2>/dev/null || true

for d in "$DATA/home" "$DATA/logs" "$DATA/run" "$DATA/state" "$DATA/opt" \
         "$DATA/npm-global" "$DATA/npm-cache" "$DATA/pnpm-store"; do
    chown 1:1 "$d" 2>/dev/null || true
done
chown 1:1 /storage/emulated/0/DSH /storage/emulated/0/DSH/workspace /storage/emulated/0/DSH/npm 2>/dev/null || true

chmod 0755 "$MODPATH/bin/"* "$MODPATH/service.sh" "$MODPATH/boot-completed.sh" \
      "$MODPATH/action.sh" 2>/dev/null || true

ui_print "- 安装完成。"
ui_print "- 必须重启设备。"
ui_print "- 首次开机会在后台解压 Alpine/DSH，约需 10–60 秒。"
ui_print "- 进度：/data/adb/dsh/logs/bootstrap.log"
