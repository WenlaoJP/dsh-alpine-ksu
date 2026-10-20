#!/system/bin/sh
# Action/WebUI helper. Runs as root from KernelSU.
case "$0" in
  */*) MODDIR=${0%/*} ;;
  *)   MODDIR=$(pwd) ;;
esac
DATA=/data/adb/dsh
STATE="$DATA/state"
RUN="$DATA/run"
LOGD="$DATA/logs"
STOPPED="$STATE/stopped"
mkdir -p "$STATE" "$RUN" "$LOGD"

alive() { [ -n "${1:-}" ] && [ -f "$1" ] && kill -0 "$(cat "$1" 2>/dev/null)" 2>/dev/null; }
pid_of() { alive "$1" && cat "$1" 2>/dev/null || echo none; }
uid_of() {
    P="$1"
    [ "$P" = none ] && { echo none; return; }
    awk '/^Uid:/{print $2; exit}' "/proc/$P/status" 2>/dev/null | sed 's/^$/none/'
}
dsh_url() {
    U="$(cat "$STATE/dsh-url.txt" 2>/dev/null || true)"
    [ -n "$U" ] || U="$(tail -n 500 "$LOGD/dsh.log" 2>/dev/null | grep -oE 'http://127\.0\.0\.1:3080/\?token=[A-Za-z0-9_-]+' | tail -1)"
    echo "${U:-none}"
}
open_url() {
    U="$1"
    [ -n "$U" ] && [ "$U" != none ] || { echo "no URL available" >&2; return 1; }
    am start --user 0 -a android.intent.action.VIEW -d "$U" -f 0x10000000 2>&1
}
kill_pidfile() {
    F="$1"; SIG="${2:-TERM}"
    [ -f "$F" ] || return 0
    P="$(cat "$F" 2>/dev/null)"
    [ -n "$P" ] && kill "-$SIG" "$P" 2>/dev/null || true
}
kill_all() {
    kill_pidfile "$RUN/service-boot.pid" TERM
    kill_pidfile "$RUN/watchdog.pid" TERM
    kill_pidfile "$RUN/supervisor.pid" TERM
    kill_pidfile "$RUN/dsh.pid" TERM
    kill_pidfile "$RUN/ttyd.pid" TERM
    if [ -f "$RUN/bootstrap.lock/pid" ]; then
        P="$(cat "$RUN/bootstrap.lock/pid" 2>/dev/null)"
        [ -n "$P" ] && kill -TERM "$P" 2>/dev/null || true
    fi
    sleep 2
    kill_pidfile "$RUN/service-boot.pid" KILL
    kill_pidfile "$RUN/watchdog.pid" KILL
    kill_pidfile "$RUN/supervisor.pid" KILL
    kill_pidfile "$RUN/dsh.pid" KILL
    kill_pidfile "$RUN/ttyd.pid" KILL
    if [ -f "$RUN/bootstrap.lock/pid" ]; then
        P="$(cat "$RUN/bootstrap.lock/pid" 2>/dev/null)"
        [ -n "$P" ] && kill -KILL "$P" 2>/dev/null || true
    fi
    rm -f "$RUN/service-boot.pid" "$RUN/watchdog.pid" "$RUN/supervisor.pid" \
          "$RUN/dsh.pid" "$RUN/ttyd.pid"
    rm -rf "$RUN/launch.lock" "$RUN/bootstrap.lock"
}
unmount_all() {
    for m in sdcard home/dsh opt/dsh var/log/dsh run/dsh run/dsh-state dev/pts dev sys proc; do
        umount -l "$DATA/rootfs/$m" 2>/dev/null || true
    done
}

case "${1:-status}" in
    status)
        SP="$(pid_of "$RUN/supervisor.pid")"
        DP="$(pid_of "$RUN/dsh.pid")"
        TP="$(pid_of "$RUN/ttyd.pid")"
        if [ -f "$STOPPED" ]; then echo "service_state=stopped"; elif [ "$SP" != none ]; then echo "service_state=running"; else echo "service_state=stopped-or-failed"; fi
        echo "supervisor_pid=$SP"
        echo "supervisor_uid=$(uid_of "$SP")"
        echo "dsh_pid=$DP"
        echo "dsh_uid=$(uid_of "$DP")"
        echo "ttyd_pid=$TP"
        echo "ttyd_uid=$(uid_of "$TP")"
        echo "rootfs_version=$(cat "$DATA/.rootfs-version" 2>/dev/null || echo none)"
        CUR="$(readlink "$DATA/opt/dsh/current" 2>/dev/null || true)"
        if [ -n "$CUR" ]; then echo "dsh_version=${CUR##*/}"; else echo "dsh_version=none"; fi
        echo "ttyd_user=dsh"
        echo "ttyd_pass=$(cat "$STATE/ttyd.pass" 2>/dev/null || echo none)"
        echo "dsh_url=$(dsh_url)"
        echo "ttyd_url=http://127.0.0.1:7681/"
        ;;
    open)
        case "${2:-dsh}" in
            dsh) open_url "$(dsh_url)" ;;
            ttyd) open_url "http://127.0.0.1:7681/" ;;
            *) echo "usage: action.sh open dsh|ttyd" >&2; exit 2 ;;
        esac
        ;;
    start)
        rm -f "$STOPPED"
        if alive "$RUN/watchdog.pid" || alive "$RUN/service-boot.pid" || alive "$RUN/supervisor.pid"; then echo "already running"; exit 0; fi
        if command -v setsid >/dev/null 2>&1; then setsid "$MODDIR/bin/dsh-service-boot" >>"$LOGD/action.log" 2>&1 & else nohup "$MODDIR/bin/dsh-service-boot" >>"$LOGD/action.log" 2>&1 & fi
        echo "start requested"
        ;;
    stop)
        touch "$STOPPED"
        kill_all
        unmount_all
        echo "stopped"
        ;;
    restart)
        touch "$STOPPED"
        kill_all
        unmount_all
        sleep 1
        rm -f "$STOPPED"
        if command -v setsid >/dev/null 2>&1; then setsid "$MODDIR/bin/dsh-service-boot" >>"$LOGD/action.log" 2>&1 & else nohup "$MODDIR/bin/dsh-service-boot" >>"$LOGD/action.log" 2>&1 & fi
        echo "restart requested"
        ;;
    log)
        case "${2:-dsh}" in
            dsh) tail -n 300 "$LOGD/dsh.log" 2>/dev/null ;;
            bootstrap) tail -n 300 "$LOGD/bootstrap.log" 2>/dev/null; tail -n 100 "$LOGD/bootstrap-launch.log" 2>/dev/null ;;
            launch) tail -n 300 "$LOGD/launch.log" 2>/dev/null ;;
            supervisor) tail -n 300 "$LOGD/supervisor.log" 2>/dev/null ;;
            service) tail -n 300 "$LOGD/service.log" 2>/dev/null; tail -n 300 "$LOGD/boot-completed.log" 2>/dev/null ;;
            ttyd) tail -n 300 "$LOGD/ttyd.log" 2>/dev/null ;;
            *) echo "usage: action.sh log dsh|bootstrap|launch|supervisor|service|ttyd" >&2; exit 2 ;;
        esac
        ;;
    diag)
        echo "=== status ==="; sh "$MODDIR/action.sh" status
        echo "=== bootstrap.log ==="; tail -n 200 "$LOGD/bootstrap.log" 2>/dev/null
        echo "=== bootstrap-launch.log ==="; tail -n 100 "$LOGD/bootstrap-launch.log" 2>/dev/null
        echo "=== launch.log ==="; tail -n 150 "$LOGD/launch.log" 2>/dev/null
        echo "=== service.log ==="; tail -n 100 "$LOGD/service.log" 2>/dev/null
        echo "=== boot-completed.log ==="; tail -n 100 "$LOGD/boot-completed.log" 2>/dev/null
        echo "=== supervisor.log ==="; tail -n 100 "$LOGD/supervisor.log" 2>/dev/null
        echo "=== dsh.log ==="; tail -n 200 "$LOGD/dsh.log" 2>/dev/null
        echo "=== ttyd.log ==="; tail -n 100 "$LOGD/ttyd.log" 2>/dev/null
        echo "=== mounts ==="; grep -E 'dsh|rootfs|sdcard' /proc/mounts 2>/dev/null | head -80
        ;;
    *)
        echo "usage: action.sh status|open dsh|open ttyd|log [dsh|bootstrap|launch|supervisor|service|ttyd]|diag|start|stop|restart"
        exit 2
        ;;
esac
