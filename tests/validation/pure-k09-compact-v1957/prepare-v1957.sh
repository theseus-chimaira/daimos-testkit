#!/bin/sh
# Repack only disposable TSFS test media. Keep all executable bytes,
# boot words, volume identity, member count and physical tape timing.
set -eu
test "$#" = 2
b=$(cd "$1" && pwd)
mkdir "$2"
w=$(cd "$2" && pwd)
awk '$1=="D" || $2=="/SYSTEM/INIT" || $2=="/SYSTEM/EXEC/MOUNTALL" || $2 ~ /^\/CONFIG\// {print}' "$b/tsfs-root.manifest" >"$w/manifest"
test "$(grep -c '^F /SYSTEM/INIT ' "$w/manifest")" = 1
test "$(grep -c '^F /SYSTEM/EXEC/MOUNTALL ' "$w/manifest")" = 1
builder="$b/mktsfs-v1461"
if test "${V1957_DATA_MEMBER:-0}" = 1; then
    : "${DAIMOS_REPO:?source checkout required for locality experiment}"
    host="$DAIMOS_REPO/tools/host"
    # Test-only allocator start member. No production tool or format
    # changes. tsfscheck must independently validate every output.
    python3 - "$host/mktsfs.c" "$w/mktsfs-locality-v1957.c" <<'PY2'
from pathlib import Path
import sys
src, dst = map(Path, sys.argv[1:])
s = src.read_text()
assert s.count("        data_member = 0U;") == 1
dst.write_text(s.replace("        data_member = 0U;",
                         "        data_member = 1U;"))
PY2
    builder="$w/mktsfs-locality-v1957"
    "${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -I"$host" \
        -o "$builder" "$w/mktsfs-locality-v1957.c" \
        "$host/tsfs-format.c" "$host/d6block-codec-v1452.c"
fi
"$builder" -n 3 -i 1:1 -g 1 -m "$w/manifest" -b "$b/kinit.lowmem.words" -o "$w/root"
"$b/tsfscheck-v1461" "$w/root0.dta" "$w/root1.dta" "$w/root2.dta" >"$w/check.log"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
if test "${V1957_DATA_MEMBER:-0}" = 1; then
    "$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$w/manifest" -b "$b/kinit.lowmem.words" -o "$w/reference"
    "$b/tsfscheck-v1461" "$w/reference0.dta" "$w/reference1.dta" "$w/reference2.dta" >"$w/reference-check.log"
    python3 "$here/verify-layout-v1957.py" "$w/reference" "$w/root" >"$w/layout.log"
fi
python3 - "$b" "$w" <<'PY'
import hashlib, shutil, sys
from pathlib import Path
b,w=map(Path,sys.argv[1:])
lines=[]
for line in (b/'boot.ini').read_text().splitlines():
    if line=='exit' or line.startswith(('attach -q dsk','attach -q dr','attach -q mtc')):
        continue
    if line.startswith('set cpu '):
        line='set cpu 48k'
    if line.startswith('attach -q dtc'):
        f=line.split()
        unit=int(f[2][3:])
        dst=w/(f[2]+'.tap')
        shutil.copyfile(w/('root%d.dta'%unit) if unit<3 else f[3],dst)
        line='attach -q '+f[2]+' '+str(dst)
    if line.startswith('attach -q -n '):
        f=line.split()
        line='attach -q -n '+f[3]+' '+str(w/(f[3]+'.out'))
    if line.startswith('set -q -n log '):
        line='set -q -n log '+str(w/'simh.log')
    lines.append(line)
assert 'set cpu 48k' in lines
assert sum(l.startswith('attach -q dtc') for l in lines)==4
(w/'physical.ini').write_text('\n'.join(lines)+'\n')
paths=[b/'kcore.dxr',b/'pure-mres-v1612.dxr',b/'kinit.lowmem.words']
for line in (w/'manifest').read_text().splitlines():
    f=line.split()
    if f[0]=='F':
        paths.append(Path(f[2]))
paths.extend(w/('dtc%d.tap'%i) for i in range(4))
(w/'source.sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p)+'\n' for p in paths))
PY
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
port=$((34000 + ($$ % 10000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" "$w/physical.ini" "$w/headless.ini" "$port" "$((port+12000))"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -o "$w/pty-run" "$kit/tools/pty-run-v1.c"
