#!/bin/bash
# Package an already-prepared rootfs into payload/rootfs.tar.gz + dsh-baseline.tar.gz.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${BUILD:-/tmp/dsh-alpine-build}"
ROOTFS="$BUILD/rootfs"
PAYLOAD="$ROOT/payload"
DSH_VERSION="${DSH_VERSION:-0.2.1-rc.2}"
[ -d "$ROOTFS" ] || { echo "missing $ROOTFS" >&2; exit 1; }
[ -d "$ROOTFS/opt/dsh/versions/$DSH_VERSION" ] || { echo "missing DSH $DSH_VERSION" >&2; exit 1; }
mkdir -p "$PAYLOAD"

ln -sfn "versions/$DSH_VERSION" "$ROOTFS/opt/dsh/current"
chown -R 1:1 "$ROOTFS/opt/dsh"
rm -rf "$BUILD/dsh-baseline"
mv "$ROOTFS/opt/dsh" "$BUILD/dsh-baseline"
mkdir -p "$ROOTFS/opt/dsh"
rm -rf "$ROOTFS/tmp/dshbuild"
find "$ROOTFS/tmp" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
for m in proc sys dev tmp; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done

printf '%s\n' "alpine-3.24.2-full-16k-poc" > "$PAYLOAD/ROOTFS_VERSION"
tar --numeric-owner -C "$ROOTFS" \
  --exclude=./proc/\* --exclude=./sys/\* --exclude=./dev/\* --exclude=./tmp/\* \
  --exclude=./var/cache/apk/\* -cf - . | gzip -1 > "$PAYLOAD/rootfs.tar.gz"
tar --numeric-owner -C "$BUILD/dsh-baseline" -cf - . | gzip -1 > "$PAYLOAD/dsh-baseline.tar.gz"
ls -lh "$PAYLOAD"
