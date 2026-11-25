#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${V1943_BASE:?source-built v1940 build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
export PATH="$PDP10_PREFIX/bin:$PATH"
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-k07-race-v1943.XXXXXX")
trap 'echo "v1943 build evidence: $work"' EXIT
b="$work/build"
mkdir -p "$b" "$work/user"
cp -a "$V1943_BASE/." "$b/"
python3 "$here/prepare-v1943.py" "$kit/tests/diagnostics/pure-brk-pressure-v1614/test-v1614.c" "$work/user/init-v1943.c"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
incs=
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
"$cc" -std=c99 -Os $incs -S "$work/user/init-v1943.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
cp "$V1943_BASE/../user/crt0.dobj" "$V1943_BASE/../user/syscall.dobj" "$work/user/"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -o "$work/dlink-v1943" "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
"$work/dlink-v1943" --pure -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" "$work/user/crt0.dobj" "$work/user/syscall.dobj" "$work/user/init.dobj" "$("$cc" -print-libgcc-file-name)"
python3 - "$DAIMOS_REPO" "$b" <<'PY'
from pathlib import Path
import sys
repo,b=map(Path,sys.argv[1:])
k=repo/'system/kernel'
p=b/'kcore-asm/vfs.s'
s=(k/'fs/vfs.s').read_text()
assert p.read_text()==s
a='vfs_unmount_sync_v1931:\n        move    1,-1(17)'
assert s.count(a)==1
p.write_text('.globl proc_sleep_ticks\n'+s.replace(a,'''vfs_unmount_sync_v1931:
        ; Test only: hold actual DTFS barrier during real PI6 sleep.
        skipe   -2(17)
        jrst    v1943_quiesce_sleep
        jrst    v1943_quiesce_done
v1943_quiesce_sleep:
        movei   1,04000
        pushj   17,proc_sleep_ticks
        .globl v1943_quiesce_done
v1943_quiesce_done:
        move    1,-1(17)''',1))
p=b/'kcore-asm/exec.s'
s=p.read_text()
assert s==(k/'proc/exec_lowmem_pdp6.s').read_text()+(k/'proc/exec_load.s').read_text()
a='''        move    1,12
        movei   2,-011(17)              ; struct vfs_stat'''
assert s.count(a)==1
p.write_text('.globl proc_sleep_ticks\n'+s.replace(a,'''        ; Test only: exact live reservation, no provider lease held.
        ldb     0,[POINT 6,12,5]
        caie    0,5
        jrst    v1943_reserve_done
        movei   1,010000
        pushj   17,proc_sleep_ticks
        .globl v1943_reserve_done
v1943_reserve_done:
        move    1,12
        movei   2,-011(17)              ; struct vfs_stat''',1))
PY
# Retain the exact copied and instrumented source after make; fail if
# the production generator silently replaced either disposable leaf.
cp "$b/kcore-asm/vfs.s" "$work/vfs-test-v1943.s"
cp "$b/kcore-asm/exec.s" "$work/exec-test-v1943.s"
make -s -j4 -C "$DAIMOS_REPO/system/boot/pdp6" image BUILD="$b" ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc BOOT_CORE_WORDS=0140000 SIMH_CPU_KWORDS=48 TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 PROC_BOOT_USERS=1 DAIMOS_PURE_MRES_ENABLED=1 SYSTEM_INIT_DXR="$work/user/init.dxr" >"$work/build.log" 2>&1 || { tail -60 "$work/build.log"; exit 1; }
cmp "$work/vfs-test-v1943.s" "$b/kcore-asm/vfs.s"
cmp "$work/exec-test-v1943.s" "$b/kcore-asm/exec.s"
grep '^v1943_.*done' "$b/kcore.map"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -o "$work/mkdtfs-v1943" "$DAIMOS_REPO/tools/host/mkdtfs.c"
rm "$b/media/dtc3-home-v22.tap"
"$work/mkdtfs-v1943" --durable-v1550 -o "$b/media/dtc3-home-v22.tap"
python3 "$kit/tests/diagnostics/pure-quiesce-run-v1646/check-v2-v1647.py" "$b/media/dtc3-home-v22.tap"
sh "$kit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh" "$work" "$b"
echo "V1943_BUILD=$b"
