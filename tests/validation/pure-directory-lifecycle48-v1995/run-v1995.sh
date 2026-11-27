#!/bin/sh
# Reuse the accepted v1987 user workload on a current 48K directory image.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || { echo 'usage: run-v1995.sh BUILD [raw|directory]' >&2; exit 2; }
mode=${2:-directory}
case "$mode" in raw|directory) ;; *) exit 2;; esac
base=$(CDPATH= cd -- "$1" && pwd)
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
prior="$here/../pure-directory-lifecycle-v1987"
mkdir -p "$TMPDIR"
w=$(mktemp -d "$TMPDIR/pure-directory-lifecycle48-v1995-$mode.XXXXXX")
trap 'echo "v1995 48K lifecycle evidence: $w"' EXIT
b="$w/build"
mkdir -p "$b/media" "$w/user"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$w/dlink" "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
incs="-I$DAIMOS_REPO/userland/libc"
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
for part in guest post; do
    "$cc" -std=c99 -Os $incs -S "$prior/$part-v1987.c" -o "$w/user/$part.s"
    "$das" -C -F -O "$w/user/$part.dobj" "$w/user/$part.s"
done
for part in crt0 syscall; do
    "$das" -C -F -O "$w/user/$part.dobj" "$DAIMOS_REPO/userland/libc/$part.s"
done
libgcc=$("$cc" -print-libgcc-file-name)
for variant in init marked post; do
    opt=; part=guest
    case $variant in marked) opt=--compressible-mutable;; post) part=post;; esac
    "$w/dlink" --pure $opt -b 020 -o "$w/user/$variant.dxr" -M "$w/user/$variant.map" \
        "$w/user/crt0.dobj" "$w/user/syscall.dobj" "$w/user/$part.dobj" "$libgcc"
done
"$base/d6block-v1464" -x "$w/user/marked.dxr" "$w/user/comp.dxr"
for name in kcore.dxr kcore.map kinit.lowmem.words pure-mres-v1612.dxr pure-mres-v1612.map; do
    cp "$base/$name" "$b/$name"
done
python3 - "$base" "$w" <<'PY'
from pathlib import Path
import sys
base,w=map(Path,sys.argv[1:])
manifest=(base/'tsfs-root.manifest').read_text().splitlines()
manifest=[x for x in manifest if not x.startswith(('F /SYSTEM/INIT ','F /SYSTEM/COMP ','F /SYSTEM/POST '))]
for name in ('init','comp','post'):
    manifest.append('F /SYSTEM/%s %s 0555 0 0'%(name.upper(),w/'user'/(name+'.dxr')))
(w/'tsfs.manifest').write_text('\n'.join(manifest)+'\n')
boot=(base/'boot.ini').read_text()
assert 'set cpu 48k\n' in boot
for i in range(3):
    old=next(x for x in boot.splitlines() if x.startswith('attach -q dtc%d '%i))
    boot=boot.replace(old,'attach -q dtc%d %s'%(i,w/'build/media'/('dtc%d.tap'%i)))
(w/'build/boot.ini').write_text(boot)
PY
"$base/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$w/tsfs.manifest" -b "$b/kinit.lowmem.words" -o "$w/root"
"$base/tsfscheck-v1461" "$w/root0.dta" "$w/root1.dta" "$w/root2.dta"
for i in 0 1 2; do cp "$w/root$i.dta" "$b/media/dtc$i.tap"; done
python3 - "$prior" "$b" "$w/replay" "$PDP10_PREFIX" "$mode" <<'PY'
import runpy,sys
from pathlib import Path
prior,b,w,prefix=map(Path,sys.argv[1:5])
mode=sys.argv[5]
m=runpy.run_path(str(prior/'replay-v1987.py'))
sys.argv=['replay-v1987.py',str(b),str(w),str(prefix),'--core','48']
if mode=='raw':
    sys.argv.append('--raw')
    m['prior']['main'](raw_lifecycle=True)
else:
    m['prior']['main'](lifecycle=m['Lifecycle'](core=48))
PY
if [ "$mode" = raw ]; then
    python3 "$here/verify-raw-v1995.py" "$b" "$w/replay" "$base"
    exit
fi
python3 - "$prior" "$b" "$w/replay" "$base" <<'PY'
import json,runpy,sys
from pathlib import Path
prior,b,w,base=map(Path,sys.argv[1:])
m=runpy.run_path(str(prior/'verify-v1987.py'))
print(json.dumps(m['verify'](b,w,base,core=48),indent=2,sort_keys=True))
PY
python3 "$prior/test-trace-v1987.py" "$b" "$w/replay" "$base" --core 48
