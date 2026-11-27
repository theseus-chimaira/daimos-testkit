#!/bin/sh
# Test actual INIT/LOGIN/DSH with a test-only PURE + mutable DXR2 link.
# The production DSH and all input media remain unchanged.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
export PATH="$PDP10_PREFIX/bin:$PATH"
[ "$#" -eq 4 ] || { echo 'usage: run-v1997.sh BUILD USERLAND_BUILD_ROOT raw|directory normal|marked' >&2; exit 2; }
b=$(CDPATH= cd -- "$1" && pwd)
u=$(CDPATH= cd -- "$2/userland" && pwd)
case "$3" in raw|directory) mode=$3;; *) exit 2;; esac
variant=$4
case "$variant" in normal|marked) ;; *) exit 2;; esac
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
mkdir -p "$TMPDIR"
w=$(mktemp -d "$TMPDIR/pure-directory-dsh-v1997-$mode-$variant.XXXXXX")
trap 'echo "v1997 $mode $variant evidence: $w"' EXIT
# Use the actual source linker and exactly the normal DSH input order/fold plan.
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$w/dlink" \
    "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
lib=$(pdp10-dec-none-gcc -print-libgcc-file-name)
"$w/dlink" --pure --compressible-mutable --daimos-uuo-relax -b 020 \
    --fold-plan "$u/dsh.fold" -o "$w/dsh.dxr" -M "$w/dsh.map" \
    "$u/dsh/libc/crt0.dobj" "$u/dsh/libc/syscall.dobj" \
    "$u/dsh/libc/syscall_helpers.dobj" "$u/dsh/libc/gcc_startup.dobj" \
    "$u/dsh/dsh/dsh_var_pdp6.dobj" "$u/dsh/libc/u.dobj" "$u/dsh/libc/text.dobj" \
    "$u/dsh/dsh/dsh_s6.dobj" "$u/dsh/dsh/dsh_lex.dobj" \
    "$u/dsh/dsh/dsh_parse.dobj" "$u/dsh/dsh/dsh_env.dobj" \
    "$u/dsh/dsh/dsh_heap.dobj" "$u/dsh/dsh/dsh_exec.dobj" \
    "$u/dsh/dsh/dsh.dobj" "$lib"
python3 - "$b" "$u" "$w" "$mode" "$variant" <<'PY'
from pathlib import Path
import hashlib
import sys
b,u,w=map(Path,sys.argv[1:4])
mode=sys.argv[4]
variant=sys.argv[5]
a=(u/'dsh.dxr').read_bytes(); m=(w/'dsh.dxr').read_bytes()
assert len(a)==len(m) and a[:8]==m[:8] and a[24:]==m[24:], 'changed DSH payload'
word=lambda p,i:int.from_bytes(p[i:i+8],'little')
assert word(m,8)==word(a,8)|0o200000 and not word(a,8)&0o200000
assert word(m,16)==word(a,16)|(1<<35) and not word(a,16)&(1<<35)
symbols=(b/'pure-mres-v1612.map').read_text()
assert ('proc_pure_bitmap_restore_v1980' in symbols)==(mode=='directory')
boot=(b/'boot.ini').read_text()
assert 'set cpu 48k\n' in boot or 'set cpu 64k\n' in boot
manifest=(b/'tsfs-root.manifest').read_text().splitlines()
assert sum(x.startswith('F /SYSTEM/EXEC/DSH ') for x in manifest)==1
manifest=[('F /SYSTEM/EXEC/DSH %s 0555 0 0'%(w/'dsh.dxr' if variant=='marked' else u/'dsh.dxr')) if x.startswith('F /SYSTEM/EXEC/DSH ') else x for x in manifest]
(w/'tsfs.manifest').write_text('\n'.join(manifest)+'\n')
(w/'image-sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p)+'\n' for p in (u/'dsh.dxr',w/'dsh.dxr',b/'kcore.dxr',b/'pure-mres-v1612.dxr',b/'kinit.lowmem.words')))
print('PASS: identical normal DSH payload; only PURE and mutable header flags differ')
PY
# Optional pressure workload consists of a small real DSH child and an
# unmarked large grandchild. No changes to kernel or DSH source.
if [ "${V1997_DIRECT:-0}" = 1 ]; then
    [ "$variant" = marked ] || exit 2
    V1997_PRESSURE_WORDS=${V1997_PRESSURE_WORDS:-8192}
fi
if [ -n "${V1997_PRESSURE_WORDS:-}" ]; then
    case "$V1997_PRESSURE_WORDS" in *[!0-9]*|'') exit 2;; esac
    src="$DAIMOS_REPO/system/kernel"
    incs="-I$DAIMOS_REPO/userland/libc"
    for dir in boot core drivers fs ipc mm modules proc storage; do incs="$incs -I$src/$dir"; done
    parts="pressure hold"
    [ "${V1997_DIRECT:-0}" != 1 ] || parts="direct-init hold"
    for part in $parts; do
        pdp10-dec-none-gcc -std=c99 -Os $incs -DHOLD_WORDS="$V1997_PRESSURE_WORDS" -S "$here/$part-v1997.c" -o "$w/$part.s"
        das -C -F -O "$w/$part.dobj" "$w/$part.s"
        "$w/dlink" -b 020 -o "$w/$part.dxr" -M "$w/$part.map" \
            "$u/dsh/libc/crt0.dobj" "$u/dsh/libc/syscall.dobj" "$w/$part.dobj" "$lib"
    done
    if [ "${V1997_DIRECT:-0}" = 1 ]; then
        awk '$1=="D" || $2=="/SYSTEM/EXEC/DSH"' "$w/tsfs.manifest" > "$w/compact.manifest"
        printf 'F /SYSTEM/INIT %s 0555 0 0\nF /SYSTEM/EXEC/K15H %s 0555 0 0\n' "$w/direct-init.dxr" "$w/hold.dxr" >> "$w/compact.manifest"
        mv "$w/compact.manifest" "$w/tsfs.manifest"
        sha256sum "$w/direct-init.dxr" "$w/hold.dxr" >> "$w/image-sha256"
    else
        printf 'F /SYSTEM/EXEC/K15PR %s 0555 0 0\nF /SYSTEM/EXEC/K15H %s 0555 0 0\n' "$w/pressure.dxr" "$w/hold.dxr" >> "$w/tsfs.manifest"
        sha256sum "$w/pressure.dxr" "$w/hold.dxr" >> "$w/image-sha256"
    fi
fi
if [ "${V1997_DIRECT:-0}" = 1 ]; then
    # Same test-only member locality experiment as v1957, independently
    # verify stock and split payloads. Do not change simulated timing.
    host="$DAIMOS_REPO/tools/host"
    python3 - "$host/mktsfs.c" "$w/mktsfs-local-v1997.c" <<'PYLOC'
from pathlib import Path
import sys
src,dst=map(Path,sys.argv[1:]);s=src.read_text()
assert s.count('        data_member = 0U;')==1
dst.write_text(s.replace('        data_member = 0U;','        data_member = 1U;'))
PYLOC
    ${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -I"$host" -o "$w/mktsfs-local-v1997" "$w/mktsfs-local-v1997.c" "$host/tsfs-format.c" "$host/d6block-codec-v1452.c"
    "$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$w/tsfs.manifest" -b "$b/kinit.lowmem.words" -o "$w/reference"
    "$w/mktsfs-local-v1997" -n 3 -i 1:1 -g 1 -m "$w/tsfs.manifest" -b "$b/kinit.lowmem.words" -o "$w/root"
    "$b/tsfscheck-v1461" "$w/reference0.dta" "$w/reference1.dta" "$w/reference2.dta"
    python3 "$here/verify-layout-v1997.py" "$w/reference" "$w/root" > "$w/layout.log"
else
    "$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$w/tsfs.manifest" -b "$b/kinit.lowmem.words" -o "$w/root"
fi
"$b/tsfscheck-v1461" "$w/root0.dta" "$w/root1.dta" "$w/root2.dta"
# Omit auxiliary disk/drum attachments (strict swapless); copy all tape media.
python3 - "$b" "$w" <<'PY'
from pathlib import Path
import shutil
import sys
b,w=map(Path,sys.argv[1:])
lines=[]
for line in (b/'boot.ini').read_text().splitlines():
    f=line.split()
    if line.startswith('attach -q '):
        dev=f[2]
        if dev.startswith(('dsk','dr')): continue
        if dev.startswith(('dtc','mtc')):
            src=w/('root'+dev[-1]+'.dta') if dev in ('dtc0','dtc1','dtc2') else Path(f[3])
            dst=w/(dev+'.tap'); shutil.copyfile(src,dst)
            line='attach -q '+dev+' '+str(dst)
    if line.startswith('attach -q -n '):
        line='attach -q -n '+f[3]+' '+str(w/(f[3]+'.out'))
    if line.startswith('set -q -n log '): line='set -q -n log '+str(w/'simh-internal.log')
    lines.append(line)
(w/'boot.ini').write_text('\n'.join(lines)+'\n')
PY
port=$((39000 + $$ % 8000))
sh "$kit/tests/lib/daimos-simh-headless.sh" "$w/boot.ini" "$w/headless.ini" "$port" "$((port+12000))"
sha256sum "$w"/dtc[012].tap > "$w/tapes-before.sha256"
if [ "${V1997_DIRECT:-0}" = 1 ]; then
    python3 "$here/direct-observe-v1997.py" "$b" "$u" "$w"
else
    python3 "$here/observe-v1997.py" "$b" "$u" "$w" "$port" "$variant"
fi
sha256sum -c "$w/tapes-before.sha256"
sha256sum -c "$w/image-sha256"
