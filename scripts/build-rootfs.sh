#!/bin/bash
# Build an Alpine aarch64 rootfs and a DSH baseline payload.
# Runs natively on aarch64, or via QEMU binfmt on x86_64 with ALLOW_CROSS=1.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${BUILD:-/tmp/dsh-alpine-build}"
ALPINE_VERSION="${ALPINE_VERSION:-3.24.2}"
ALPINE_BRANCH="${ALPINE_BRANCH:-v3.24}"
DSH_VERSION="${DSH_VERSION:-0.2.1-rc.2}"
PROFILE="${PROFILE:-full}"
ROOTFS="$BUILD/rootfs"
CACHE="$BUILD/cache"
PAYLOAD="$ROOT/payload"

log() { echo -e "\033[1;36m[build-rootfs]\033[0m $*"; }
die() { echo "[build-rootfs] ERROR: $*" >&2; exit 1; }
need_root() { [ "$(id -u)" = "0" ] || die "run as root"; }
need_arch() {
    if [ "$(uname -m)" = "aarch64" ]; then return 0; fi
    [ "${ALLOW_CROSS:-0}" = "1" ] || die "must build on aarch64 (set ALLOW_CROSS=1 for QEMU cross-build)"
    [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] || die "qemu-aarch64 binfmt is not registered"
}

need_root
need_arch
mkdir -p "$BUILD" "$CACHE" "$PAYLOAD"

if [ ! -f "$CACHE/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz" ]; then
    log "downloading Alpine ${ALPINE_VERSION}"
    curl -fL --retry 3 \
      "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/aarch64/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz" \
      -o "$CACHE/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz"
fi

log "creating rootfs"
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"
tar -xzf "$CACHE/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz" -C "$ROOTFS"

cat >"$ROOTFS/etc/apk/repositories" <<REPOS
https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/main
https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/community
REPOS
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
echo 'nameserver 1.1.1.1' >>"$ROOTFS/etc/resolv.conf"
echo 'nameserver 8.8.8.8' >>"$ROOTFS/etc/resolv.conf"

cleanup() {
    umount -l "$ROOTFS/proc" 2>/dev/null || true
    umount -l "$ROOTFS/sys" 2>/dev/null || true
    umount -l "$ROOTFS/dev" 2>/dev/null || true
    umount -l "$ROOTFS/tmp" 2>/dev/null || true
}
trap cleanup EXIT
mkdir -p "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/dev" "$ROOTFS/tmp"
mount -t proc proc "$ROOTFS/proc"
mount -o bind /sys "$ROOTFS/sys"
mount -o bind /dev "$ROOTFS/dev"
chmod 1777 "$ROOTFS/tmp"

log "installing base packages"
BASE_PKGS="nodejs npm pnpm ttyd tmux bash git ripgrep ca-certificates curl setpriv coreutils"
if [ "$PROFILE" = "full" ]; then
    BASE_PKGS="$BASE_PKGS build-base python3 cmake nodejs-dev linux-headers"
fi
chroot "$ROOTFS" /bin/sh -c "apk update && apk add --no-cache $BASE_PKGS"

log "installing rootfs overlay"
mkdir -p "$ROOTFS/usr/local/bin" "$ROOTFS/etc/profile.d"
cp -R "$ROOT/rootfs-overlay/." "$ROOTFS/"
chmod 0755 "$ROOTFS/usr/local/bin/"*
chmod 0644 "$ROOTFS/etc/profile.d/dsh.sh" "$ROOTFS/etc/motd" 2>/dev/null || true

mkdir -p "$ROOTFS"/{home/dsh,opt/dsh,run/dsh,run/dsh-state,var/log/dsh,sdcard,workspace,npm}
ln -sfn /sdcard/DSH/workspace "$ROOTFS/workspace"
ln -sfn /sdcard/DSH/npm "$ROOTFS/npm"
rm -rf "$ROOTFS/home/dsh"/* "$ROOTFS/home/dsh"/.[!.]* 2>/dev/null || true

log "installing DSH ${DSH_VERSION} (this can take several minutes)"
DSH_DIR="$ROOTFS/opt/dsh"
mkdir -p "$DSH_DIR/versions/$DSH_VERSION" "$ROOTFS/tmp/dshbuild"
chown -R 1:1 "$DSH_DIR" "$ROOTFS/tmp/dshbuild"
chroot "$ROOTFS" /bin/setpriv --reuid=1 --regid=1 --groups=3003 --no-new-privs \
    /bin/sh -c "
      set -eu
      export HOME=/tmp/dshbuild
      export npm_config_cache=/tmp/dshbuild/.npm
      export PATH=/usr/local/bin:/usr/bin:/bin
      cd '/opt/dsh/versions/${DSH_VERSION}'
      npm init -y >/dev/null 2>&1 || true
      npm install --no-audit --no-fund '@deepseek-ai/dsh@${DSH_VERSION}'
      npm rebuild node-pty --build-from-source
      KDIR='/opt/dsh/versions/${DSH_VERSION}/node_modules/@koromix/koffi-linux-arm64'
      if [ -d \"\$KDIR\" ]; then
        cat >\"\$KDIR/index.js\" <<'KEOF'
let native = null;
let err = null;
try { native = require('./musl_arm64/koffi.node'); } catch (e) { err = e; }
if (native == null) throw err;
module.exports = native;
KEOF
      fi
      node -e \"require('node-pty'); require('koffi'); require('sharp'); console.log('native ok')\"
      node node_modules/@deepseek-ai/dsh/lib/bin.js --version
      /usr/local/bin/dsh-prune /opt/dsh/versions/${DSH_VERSION}
      touch .installed
    "

ln -sfn "versions/$DSH_VERSION" "$DSH_DIR/current"
chown -R 1:1 "$DSH_DIR"

log "checking ELF page alignment"
check_align() {
    local f="$1"
    [ -f "$f" ] || return 0
    local a n
    a="$(readelf -l "$f" 2>/dev/null | awk '/LOAD/{getline; print $NF; exit}')"
    [ -n "$a" ] || { echo "  ? $f"; return 0; }
    n=$((a))
    if [ "$n" -lt 16384 ]; then echo "  BAD align=$a $f" >&2; return 1; fi
    echo "  ok align=$a $f"
}
check_align "$ROOTFS/usr/bin/node"
check_align "$ROOTFS/lib/ld-musl-aarch64.so.1"
for f in $(find "$DSH_DIR" -name '*.node' -o -name '*.so*' 2>/dev/null | head -50); do
    check_align "$f" || die "ELF alignment failed for $f"
done

log "packaging rootfs and DSH baseline"
rm -rf "$BUILD/dsh-baseline"
mv "$DSH_DIR" "$BUILD/dsh-baseline"
mkdir -p "$ROOTFS/opt/dsh"
rm -rf "$ROOTFS/tmp/dshbuild" "$ROOTFS"/tmp/* 2>/dev/null || true
cleanup

printf '%s\n' "alpine-${ALPINE_VERSION}-${PROFILE}-16k-poc" >"$PAYLOAD/ROOTFS_VERSION"
tar --numeric-owner -C "$ROOTFS" \
  --exclude=./proc/\* --exclude=./sys/\* --exclude=./dev/\* --exclude=./tmp/\* \
  --exclude=./var/cache/apk/\* -czf "$PAYLOAD/rootfs.tar.gz" .
tar --numeric-owner -C "$BUILD/dsh-baseline" -czf "$PAYLOAD/dsh-baseline.tar.gz" .

log "done"
ls -lh "$PAYLOAD"
