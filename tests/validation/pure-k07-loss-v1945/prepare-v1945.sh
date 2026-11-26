#!/bin/sh
# Uninstrumented v1942 KCORE/PURE with a genuine v1944 sealed secondary.
set -eu
: "${DAIMOS_REPO:?}" "${V1945_BASE:?v1942 pressure build}" "${V1945_SEED_BUILD:?v1943 seed build}" "${V1945_SEED_TRACE:?actual completed seed trace}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
old=$(CDPATH= cd -- "$V1945_BASE" && pwd)
seedbuild=$(CDPATH= cd -- "$V1945_SEED_BUILD" && pwd)
seed=$(CDPATH= cd -- "$V1945_SEED_TRACE" && pwd)
w=$(mktemp -d "$TMPDIR/pure-k07-loss-v1945.XXXXXX")
trap 'echo "v1945 build evidence: $w"' EXIT
b="$w/build"
mkdir -p "$b" "$w/user"
grep -q "ijkccccccccdsuIE" "$seed/physical.clean"
python3 "$kit/tests/validation/pure-k07-race-v1943/check-reel-v1944.py" "$seedbuild/media/dtc3-home-v22.tap" "$seed/media/dtc3.tap" "$seedbuild/../user/comp-v1638.dxr"
python3 "$here/prepare-v1945.py" "$old/../user/init-v1941.c" "$w/user/init-v1945.c"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
incs=
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
"$cc" -std=c99 -Os $incs -S "$w/user/init-v1945.c" -o "$w/user/init.s"
"$das" -C -F -O "$w/user/init.dobj" "$w/user/init.s"
cp "$old/../user/crt0.dobj" "$old/../user/syscall.dobj" "$w/user/"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -o "$w/dlink-v1945" "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
"$w/dlink-v1945" --pure -b 020 -o "$w/user/init.dxr" -M "$w/user/init.map" "$w/user/crt0.dobj" "$w/user/syscall.dobj" "$w/user/init.dobj" "$("$cc" -print-libgcc-file-name)"
"$PDP10_PREFIX/bin/dxrcheck" "$w/user/init.dxr"
cp -a "$old/." "$b/"
cp "$old/../user/init.dxr" "$w/user/base.dxr"
cp "$seedbuild/../user/comp-v1638.dxr" "$w/user/comp-v1638.dxr"
cp "$seed/media/dtc3.tap" "$b/media/dtc3-home-v22.tap"
python3 - "$old" "$w" "$b" <<'PY'
from pathlib import Path
import sys
old,w,b=map(Path,sys.argv[1:])
s=(old/'tsfs-root.manifest').read_text()
a='F /SYSTEM/INIT '+str(old.parent/'user/init.dxr')
assert s.count(a)==1 and 'F /SYSTEM/BASE ' not in s
s=s.replace(a,'F /SYSTEM/INIT '+str(w/'user/init.dxr'),1)
s+='F /SYSTEM/BASE '+str(w/'user/base.dxr')+' 0555 0 0\n'
(b/'tsfs-root.manifest').write_text(s)
(b/'boot.ini').write_text((old/'boot.ini').read_text().replace(str(old)+'/',str(b)+'/'))
PY
"$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$b/tsfs-root.manifest" -b "$b/kinit.lowmem.words" -o "$w/tsfs-v1945"
"$b/tsfscheck-v1461" "$w/tsfs-v1945"0.dta "$w/tsfs-v1945"1.dta "$w/tsfs-v1945"2.dta
for unit in 0 1 2; do cp "$w/tsfs-v1945$unit.dta" "$b/media/dtc$unit.tap"; done
for n in kcore.dxr kinit.lowmem.words pure-mres-v1612.dxr; do cmp "$old/$n" "$b/$n"; done
# Independently formatted foreign reel, not an altered original seal.
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -o "$w/mkdtfs-v1945" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$w/mkdtfs-v1945" --durable-v1550 -o "$b/media/foreign-v1945.tap"
python3 "$kit/tests/diagnostics/pure-quiesce-run-v1646/check-v2-v1647.py" "$b/media/foreign-v1945.tap"
echo "V1945_BUILD=$b"
