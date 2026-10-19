#!/bin/sh
# Host-side smoke test of an already-built rootfs + DSH baseline.
set -eu
ROOT="${1:-build/rootfs}"
DSH="${2:-build/dsh-baseline}"
[ -d "$ROOT" ] || { echo "missing $ROOT" >&2; exit 1; }
[ -d "$DSH" ] || { echo "missing $DSH" >&2; exit 1; }
chroot "$ROOT" "$ROOT/bin/setpriv" --reuid=1 --regid=1 --groups=3003 --no-new-privs \
  /bin/sh -c 'node --version; npm --version; pnpm --version; ttyd --version 2>&1 | head -1'
mount -o bind "$DSH" "$ROOT/opt/dsh" 2>/dev/null || true
chroot "$ROOT" "$ROOT/bin/setpriv" --reuid=1 --regid=1 --groups=3003 --no-new-privs \
  /bin/sh -c 'HOME=/tmp DSH_HOME=/tmp/.dsh /usr/local/bin/dsh --version'
umount "$ROOT/opt/dsh" 2>/dev/null || true
