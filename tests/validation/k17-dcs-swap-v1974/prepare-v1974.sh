#!/bin/sh
# Derive only test user images from the accepted v1955 six-child source.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export PATH="$PDP10_PREFIX/bin:$PATH"
test "$#" = 2
src=$(cd "$1" && pwd)
mkdir "$2"
w=$(cd "$2" && pwd)
u="$w/user"
mkdir "$u"
python3 - "$src" "$u" <<'PY'
from pathlib import Path
import sys
a,b=map(Path,sys.argv[1:])
s=(a/"init-v1955.c").read_text()
def replace(x,y):
    global s
    assert s.count(x)==1,x
    s=s.replace(x,y)
replace("3U * U_PATH_WORDS + 3U","3U * U_PATH_WORDS + 4U")
replace("total = maps + 3U;","total = maps + 4U;")
replace("run->fdmap_count = 3UL;","run->fdmap_count = 4UL;")
replace("words[maps + 2U] = SYS_RUN_FD_MAP(2U, 2U);",
        "words[maps + 2U] = SYS_RUN_FD_MAP(2U, 2U);\n"
        "        words[maps + 3U] = SYS_RUN_FD_MAP(3U, 0U);")
(b/"init-v1974.c").write_text(s)
s=(a/"child-v1955.s").read_text()
replace("        movem 03,017000\n","""        movem 03,017000
        caie 01,2
        jrst __pipe_wait
        ; PID2 owns logical TTY1 while blocked on a real DCS reader.
        movei 01,3            ; NEWSESSION
        setz 02,
        uuo 077,0(1)
        caie 01,2
        jrst __bad_dcs
        movei 01,011          ; TTY_ATTACH
        movei 02,1
        uuo 077,0(1)
        caie 01,1
        jrst __bad_dcs
        movei 01,014          ; TTY_SETFG
        movei 02,2
        uuo 077,0(1)
        caie 01,2
        jrst __bad_dcs
        movei 01,027          ; TTY_SETMODE RAW
        setz 02,
        uuo 077,0(1)
        jumpn 01,__bad_dcs
        movei 01,3            ; inherited native CTY endpoint -> current TTY
        uuo 061,0(1)
        caie 01,0132          ; exactly one real TCP ASCII Z
        jrst __bad_dcs
__pipe_wait:
""")
replace("__bad_brk:\n","""__bad_dcs:
        movei 01,021
        uuo 040,0(1)
        halt .
__bad_brk:
""")
(b/"child-v1974.s").write_text(s)
PY
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
set --
for d in boot core drivers fs ipc mm modules proc storage; do
    set -- "$@" "-I$DAIMOS_REPO/system/kernel/$d"
done
"$cc" -std=c99 -Os "$@" -I"$DAIMOS_REPO/userland/libc" -S "$u/init-v1974.c" -o "$u/init.s"
"$das" -C -F -O "$u/init.dobj" "$u/init.s"
for n in crt0 syscall u checkpoint; do cp "$src/$n.dobj" "$u/$n.dobj"; done
"$das" -C -F -O "$u/child.dobj" "$u/child-v1974.s"
dlink -b 020 -o "$u/child.dxr" -M "$u/child.map" "$u/child.dobj"
dlink -b 020 -o "$u/init.dxr" -M "$u/init.map" "$u/crt0.dobj" "$u/syscall.dobj" "$u/u.dobj" "$u/init.dobj" "$u/checkpoint.dobj" "$("$cc" -print-libgcc-file-name)"
make -C "$DAIMOS_REPO/system/boot/pdp6" -j4 image DAIMOS_MACHINE=ka10 ROOT=disk BOOT=dsk BOOT_PROFILE=lowmem COMPILER=kcc BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 DAIMOS_PURE_MRES_ENABLED=0 SYSTEM_INIT_DXR="$u/init.dxr" SYSTEM_MOUNTALL_DXR="$u/child.dxr" BUILD="$w/build" >"$w/build.log" 2>&1
