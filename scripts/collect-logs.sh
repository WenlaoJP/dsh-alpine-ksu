#!/system/bin/sh
# Collect PoC diagnostics for a target-device test.
OUT=/sdcard/DSH/dsh-poc-logs-$(date +%Y%m%d-%H%M%S).txt
mkdir -p /sdcard/DSH
{
  echo "== date =="; date
  echo "== module =="; cat /data/adb/modules/dsh_alpine/module.prop 2>/dev/null; cat /data/adb/dsh/.rootfs-version 2>/dev/null
  echo "== uname =="; uname -a
  echo "== getprop =="; getprop | grep -E 'ro.build.version|ro.product.cpu|ro.kernel|init.svc' | head -100
  echo "== page size =="; getconf PAGE_SIZE 2>/dev/null
  echo "== mounts =="; cat /proc/mounts | grep -E 'dsh|sdcard' | head -100
  echo "== processes =="; ps -ef | grep -E 'dsh|ttyd|node|chroot|supervisor' | grep -v grep
  echo "== pids =="; for f in /data/adb/dsh/run/*.pid; do [ -f "$f" ] && echo "$f=$(cat "$f")"; done
  echo "== oom =="; for p in $(pgrep -f 'dsh-supervisor|dsh/lib/bin.js|ttyd' 2>/dev/null); do echo "$p uid=$(awk '/^Uid:/{print $2}' /proc/$p/status 2>/dev/null) oom=$(cat /proc/$p/oom_score_adj 2>/dev/null)"; done
  echo "== logs =="; for f in /data/adb/dsh/logs/*.log /data/adb/dsh/logs/*.log.1; do [ -f "$f" ] && { echo "--- $f"; tail -n 200 "$f"; }; done
  echo "== dmesg tail =="; dmesg 2>/dev/null | tail -n 200
  echo "== logcat tail =="; logcat -d -t 400 2>/dev/null | grep -iE 'dsh|ksu|avc|selinux' | tail -n 200
} >"$OUT" 2>&1
echo "$OUT"
