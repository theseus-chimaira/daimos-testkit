#!/bin/sh
# Test actual INIT/LOGIN/DSH with a test-only PURE + mutable DXR2 link.
# The production DSH and all input media remain unchanged.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
export PATH="$PDP10_PREFIX/bin:$PATH"
[ "$#" -eq 3 ] || { echo 'usage: run-v1995.sh BUILD USERLAND_BUILD_ROOT raw|directory' >&2; exit 2; }
b=$(CDPATH= cd -- "$1" && pwd)
u=$(CDPATH= cd -- "$2/userland" && pwd)
case "$3" in raw|directory) mode=$3;; *) exit 2;; esac
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
mkdir -p "$TMPDIR"
w=$(mktemp -d "$TMPDIR/pure-directory-dsh-v1995-$mode.XXXXXX")
trap 'echo "v1995 $mode evidence: $w"' EXIT
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
python3 - "$b" "$u" "$w" "$mode" <<'PY'
from pathlib import Path
import hashlib
import sys
b,u,w=map(Path,sys.argv[1:4])
mode=sys.argv[4]
a=(u/'dsh.dxr').read_bytes(); m=(w/'dsh.dxr').read_bytes()
assert len(a)==len(m) and a[:8]==m[:8] and a[24:]==m[24:], 'changed DSH payload'
word=lambda p,i:int.from_bytes(p[i:i+8],'little')
assert word(m,8)==word(a,8)|0o200000 and not word(a,8)&0o200000
assert word(m,16)==word(a,16)|(1<<35) and not word(a,16)&(1<<35)
symbols=(b/'pure-mres-v1612.map').read_text()
assert ('proc_pure_bitmap_restore_v1980' in symbols)==(mode=='directory')
boot=(b/'boot.ini').read_text()
assert 'set cpu 48k\n' in boot
manifest=(b/'tsfs-root.manifest').read_text().splitlines()
assert sum(x.startswith('F /SYSTEM/EXEC/DSH ') for x in manifest)==1
manifest=[('F /SYSTEM/EXEC/DSH %s 0555 0 0'%(w/'dsh.dxr')) if x.startswith('F /SYSTEM/EXEC/DSH ') else x for x in manifest]
(w/'tsfs.manifest').write_text('\n'.join(manifest)+'\n')
(w/'image-sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p)+'\n' for p in (u/'dsh.dxr',w/'dsh.dxr',b/'kcore.dxr',b/'pure-mres-v1612.dxr',b/'kinit.lowmem.words')))
print('PASS: identical normal DSH payload; only PURE and mutable header flags differ')
PY
"$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$w/tsfs.manifest" -b "$b/kinit.lowmem.words" -o "$w/root"
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
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$w/pty" "$kit/tools/pty-run-v1.c"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$w/tcp" "$kit/tools/tcp-run-v1.c"
sha256sum "$w"/dtc[012].tap > "$w/tapes-before.sha256"
sh "$kit/tools/daimos-simh-harness-v4.sh" --daimos-repo "$DAIMOS_REPO" \
    --dofile "$w/headless.ini" --pty-run "$w/pty" --tcp-run "$w/tcp" \
    --dcs-port "$port" --login ROOT --probes "$here/probes-v1995.txt" \
    --work-dir "$w/run" --markdown-report "$w/report.md" --boot-timeout "${V1995_BOOT_TIMEOUT:-300}" --timeout "${V1995_COMMAND_TIMEOUT:-120}"
sha256sum -c "$w/tapes-before.sha256"
sha256sum -c "$w/image-sha256"
echo "PASS v1995 $mode marked DSH shell probes and unchanged root media"
