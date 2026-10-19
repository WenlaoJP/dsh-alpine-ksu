#!/bin/sh
# Verify that chosen ELF binaries have >=16KB LOAD alignment.
set -eu
ROOT="${1:-build/rootfs}"
check() {
    f="$1"; [ -f "$f" ] || return 0
    a="$(readelf -l "$f" 2>/dev/null | awk '/LOAD/{getline; print $NF; exit}')"
    [ -n "$a" ] || { echo "? $f"; return 0; }
    n=$((a))
    [ "$n" -ge 16384 ] || { echo "BAD align=$a $f"; return 1; }
    echo "ok align=$a $f"
}
check "$ROOT/usr/bin/node"
check "$ROOT/lib/ld-musl-aarch64.so.1"
find "$ROOT/opt/dsh" -name '*.node' -o -name '*.so*' 2>/dev/null | while read -r f; do check "$f"; done
