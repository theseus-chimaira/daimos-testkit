#!/bin/sh
# Current KCC disk-root image with a native non-PURE swap workload.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export PATH="$PDP10_PREFIX/bin:$PATH"
test "$#" = 1
mkdir "$1"
w=$(cd "$1" && pwd)
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
u="$w/user"; b="$w/build"
mkdir "$u"
python3 - "$here/../pure-runtime-highwater-v1674" "$u" <<'PY'
from pathlib import Path
import sys
src,out=map(Path,sys.argv[1:])
s=(src/'proc-pressure-v1674.c').read_text()
def replace(a,b):
 global s
 assert s.count(a)==1,a
 s=s.replace(a,b)
replace('#define V1673_MAX_CHILDREN 9U','#define V1673_MAX_CHILDREN 6U')
replace('mem.total_words != 49152UL','mem.total_words != 65536UL')
replace('count = 9U;','count = 6U;\n        if (dsys_storagectl(SYS_STORAGECTL_SWAP) != 0)\n                return 41;')
a=s.index('        v1673_line("V1673 TRIGGER RUN')
b=s.index('        v1673_meminfo("V1673 PRESSURE")',a)
s=s[:a]+s[b:]
replace('        v1673_meminfo("V1673 REAPED");',
        '        if (dsys_close(pipe_read_fd) != 0 || dsys_close(pipe_write_fd) != 0)\n'
        '                return 42;\n'
        '        v1673_meminfo("V1673 REAPED");')
s=s.replace('/* v1674 physical RAW PURE MM pressure, deterministic pipe-held children.\n * The production KCORE and original INIT executable are NOT modified.\n * This C89 fixture replaces /SYSTEM/INIT only in a disposable TSFS image.\n */','/* v1955: six enlarged children force real disk-backed swap. */')
s=s.replace('/* Test only 48K PDP-6. Nine pipe-blocked PURE children must\n'
            '         * remain eligible for RAW reclamation until B, regardless of\n'
            '         * host wall-clock and simulator single-step throughput.\n'
            '         * A tenth RUN must refuse due to original-MM fragmentation. */',
            '/* Six 8192-word APRs and PID1 exceed native 64K free RAM. */')
(out/'init-v1955.c').write_text(s)
s=(src/'pipe-child-v1674.s').read_text()
s=s.replace('        subi 01,6\n        jumpg 01,__sleep\n        movei 02,06000         ; 3072 logical words in the child APR','        movei 02,020000        ; 8192 logical words in the child APR')
assert 'movei 02,020000' in s
# Additional high-end canary proves that the grown part is preserved.
s=s.replace('__sleep:\n','__sleep:\n        uuo 076,0\n        movei 03,065432\n        xor 03,1\n        movem 03,017000\n')
s=s.replace('        came 03,02500          ; compare retained writable suffix\n        jrst __bad_canary','        came 03,02500          ; compare retained writable suffix\n        jrst __bad_canary\n        movei 03,065432\n        xor 03,1\n        came 03,017000\n        jrst __bad_canary')
(out/'child-v1955.s').write_text(s)
PY
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
incs="-I$DAIMOS_REPO/userland/libc"
for d in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
incs="$incs -I$PDP10_PREFIX/include"
"$cc" -std=c99 -Os $incs -S "$u/init-v1955.c" -o "$u/init.s"
"$das" -C -F -O "$u/init.dobj" "$u/init.s"
for n in crt0 syscall u; do
    if test "$n" = u; then
        "$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$u/u.s"
        "$das" -C -F -O "$u/u.dobj" "$u/u.s"
    else
        "$das" -C -F -O "$u/$n.dobj" "$DAIMOS_REPO/userland/libc/$n.s"
    fi
done
"$das" -C -F -O "$u/checkpoint.dobj" "$here/../pure-runtime-reclaim-v1673/checkpoint-v1673.s"
"$das" -C -F -O "$u/child.dobj" "$u/child-v1955.s"
dlink -b 020 -o "$u/child.dxr" -M "$u/child.map" "$u/child.dobj"
dlink -b 020 -o "$u/init.dxr" -M "$u/init.map" "$u/crt0.dobj" "$u/syscall.dobj" "$u/u.dobj" "$u/init.dobj" "$u/checkpoint.dobj" "$("$cc" -print-libgcc-file-name)"
git -C "$DAIMOS_REPO" rev-parse HEAD >"$w/source.commit"
git -C "$DAIMOS_REPO" status --porcelain >"$w/source.status"
test ! -s "$w/source.status"
make -C "$DAIMOS_REPO/system/boot/pdp6" -j4 image BUILD="$b" ROOT=disk BOOT=dsk BOOT_PROFILE=lowmem COMPILER=kcc BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 DAIMOS_PURE_MRES_ENABLED=0 SYSTEM_INIT_DXR="$u/init.dxr" SYSTEM_MOUNTALL_DXR="$u/child.dxr" >"$w/build.log" 2>&1
echo "v1955 disk-swap build $b"
