#!/bin/bash
# Package the KernelSU module ZIP. Payload tarballs are produced by build-rootfs.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(sed -n 's/^version=//p' module.prop | head -1)"
OUT="$ROOT/dist/dsh_alpine-${VERSION}.zip"
mkdir -p "$ROOT/dist"
[ -f payload/rootfs.tar.gz ] || { echo "missing payload/rootfs.tar.gz; run scripts/build-rootfs.sh" >&2; exit 1; }
[ -f payload/dsh-baseline.tar.gz ] || { echo "missing payload/dsh-baseline.tar.gz" >&2; exit 1; }

python3 - "$OUT" <<'PY'
import os, sys, zipfile
out=sys.argv[1]
root=os.getcwd()
include=['module.prop','customize.sh','hotinstall.sh','service.sh','boot-completed.sh','uninstall.sh','action.sh','bin','extras','rootfs-overlay','webroot','payload','scripts','README.md']
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for item in include:
        p=os.path.join(root,item)
        if not os.path.exists(p): continue
        if os.path.isfile(p):
            z.write(p,item)
        else:
            for dirpath,dirs,files in os.walk(p):
                dirs[:] = [d for d in dirs if d not in ('build','dist','.git')]
                for f in files:
                    fp=os.path.join(dirpath,f)
                    rel=os.path.relpath(fp,root)
                    z.write(fp,rel)
print(out)
PY
ls -lh "$OUT"
