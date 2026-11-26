#!/bin/sh
# Fresh source-matched KCC kernel; GCC-built test-only PID1 / COMP.
set -eu
test "$#" = 3 || { echo "usage: $0 WORK {48|64} {general|strict}" >&2; exit 2; }
work=$1
core=$2
variant=$3
case "$core" in 48) children=5; words=0140000;; 64) children=9; words=0200000;; *) exit 2;; esac
case "$variant" in general) strict=0;; strict) strict=1;; *) exit 2;; esac
: "${DAIMOS_REPO:?source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export PATH="$PDP10_PREFIX/bin:$PATH"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
mkdir "$work"
work=$(CDPATH= cd -- "$work" && pwd)
u="$work/user"
b="$work/build"
mkdir "$u"
python3 "$kit/tests/diagnostics/pure-full-restore-v1638/prepare-v1638.py" \
    "$kit/tests/diagnostics/pure-brk-pressure-v1614/test-v1614.c" "$u/init.c"
python3 - "$u/init.c" "$children" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text()
assert s.count('#define P14_CHILDREN         6U')==1
s=s.replace('#define P14_CHILDREN         6U',
            '#define P14_CHILDREN         '+sys.argv[2]+'U')
p.write_text(s)
PY
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
incs="-I$DAIMOS_REPO/userland/libc"
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
"$cc" -std=c99 -Os $incs -S "$u/init.c" -o "$u/init.s"
"$das" -C -F -O "$u/init.dobj" "$u/init.s"
for name in crt0 syscall; do
    "$das" -C -F -O "$u/$name.dobj" "$DAIMOS_REPO/userland/libc/$name.s"
done
libgcc=$("$cc" -print-libgcc-file-name)
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/dlink-v1951" "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
"$work/dlink-v1951" --pure -b 020 -o "$u/init.dxr" -M "$u/init.map" \
    "$u/crt0.dobj" "$u/syscall.dobj" "$u/init.dobj" "$libgcc"
"$PDP10_PREFIX/bin/dxrcheck" -d "$u/init.dxr" >"$u/dxrcheck.log"
grep -q 'purity=PURE' "$u/dxrcheck.log"
git -C "$DAIMOS_REPO" rev-parse HEAD >"$work/source.commit"
git -C "$DAIMOS_REPO" status --porcelain >"$work/source.status"
test ! -s "$work/source.status"
make -C "$DAIMOS_REPO/system/boot/pdp6" -j4 image BUILD="$b" \
    ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=kcc \
    BOOT_CORE_WORDS="$words" SIMH_CPU_KWORDS="$core" \
    TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 DAIMOS_PURE_MRES_ENABLED=1 \
    DAIMOS_PBM_V1667=0 DAIMOS_SWAPLESS_ONLY_V1668="$strict" \
    SYSTEM_INIT_DXR="$u/init.dxr" >"$work/build.log" 2>&1
sh "$kit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh" "$work" "$b"
echo "KCC $core $variant $children-child build=$b"
