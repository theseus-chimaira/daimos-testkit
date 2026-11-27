#!/bin/sh
# Repackage the accepted, unchanged source-built v1985 kernel.
set -eu
: "${DAIMOS_REPO:?}" "${V1987_BASE_BUILD:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
base=$V1987_BASE_BUILD
work=$(mktemp -d "$TMPDIR/pure-directory-lifecycle-build-v1987.XXXXXX")
trap 'echo "v1987 build evidence: $work"' EXIT
b=$work/build
mkdir -p "$b/media" "$work/user"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
link="$work/dlink-v1987"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$link" "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
incs="-I$DAIMOS_REPO/userland/libc"
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
for part in guest post; do
    "$cc" -std=c99 -Os $incs -S "$here/$part-v1987.c" -o "$work/user/$part.s"
    "$das" -C -F -O "$work/user/$part.dobj" "$work/user/$part.s"
done
for part in crt0 syscall; do
    "$das" -C -F -O "$work/user/$part.dobj" "$DAIMOS_REPO/userland/libc/$part.s"
done
libgcc=$("$cc" -print-libgcc-file-name)
for mode in init marked post; do
    opt=; part=guest
    case $mode in marked) opt=--compressible-mutable;; post) part=post;; esac
    "$link" --pure $opt -b 020 -o "$work/user/$mode.dxr" -M "$work/user/$mode.map" \
        "$work/user/crt0.dobj" "$work/user/syscall.dobj" "$work/user/$part.dobj" "$libgcc"
done
"$base/d6block-v1464" -x "$work/user/marked.dxr" "$work/user/comp.dxr"
# Bind the new tapes to the actual existing KINIT/KCORE and MRES artifacts.
for name in kcore.dxr kcore.map kinit.lowmem.words pure-mres-v1612.dxr pure-mres-v1612.map; do
    cp "$base/$name" "$b/$name"
done
python3 - "$base" "$work" <<'PY'
from pathlib import Path
import sys
base,w=map(Path,sys.argv[1:])
manifest=(base.parent/'tsfs.manifest').read_text().splitlines()
manifest=[x for x in manifest if not x.startswith(('F /SYSTEM/INIT ','F /SYSTEM/COMP ','F /SYSTEM/POST '))]
for name in ('init','comp','post'):
    manifest.append('F /SYSTEM/%s %s 0555 0 0'%(name.upper(),w/'user'/ (name+'.dxr')))
(w/'tsfs.manifest').write_text('\n'.join(manifest)+'\n')
boot=(base/'boot.ini').read_text()
for i in range(3):
    old=next(x for x in boot.splitlines() if x.startswith('attach -q dtc%d '%i))
    boot=boot.replace(old,'attach -q dtc%d %s'%(i,w/'build/media'/('dtc%d.tap'%i)))
(w/'build/boot.ini').write_text(boot)
PY
"$base/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$work/tsfs.manifest" -b "$b/kinit.lowmem.words" -o "$work/root-v1987"
"$base/tsfscheck-v1461" "$work/root-v1987"0.dta "$work/root-v1987"1.dta "$work/root-v1987"2.dta
for i in 0 1 2; do cp "$work/root-v1987$i.dta" "$b/media/dtc$i.tap"; done
printf 'V1987_BUILD=%s\n' "$b"
