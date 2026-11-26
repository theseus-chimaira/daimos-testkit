#!/bin/sh
# Use exact v1955 native six-child PID1/child images on either KA10 root.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
: "${V1973_DCS_PORT:?unique unused TCP port required}"
test "$#" = 2
b=$(cd "$1" && pwd)
mkdir "$2"
w=$(cd "$2" && pwd)
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -o "$w/pty-run" "$kit/tools/pty-run-v1.c"
mk="$PDP10_PREFIX/bin/mkauxstore"
"$mk" --blank "$w/rm10.drm" --blocks 05214
"$mk" -i "$w/rm10.drm" --confirm-destructive --backstore-blocks 01000 \
    --logstore-blocks 0 --cache-blocks 0 --d6fs-base 1 --d6fs-blocks 04213 \
    --d6fs-super-a 0 --d6fs-super-b 1
cp "$w/rm10.drm" "$w/rm10-before.drm"
python3 - "$b" "$w" <<'PY'
from pathlib import Path
import os,sys,shutil
b,w=map(Path,sys.argv[1:])
lines=[]
for line in (b/'boot.ini').read_text().splitlines():
    if line=='exit':
        continue
    if line=='set fha disabled':
        lines += ['set fha enabled','set fha0 rm10','attach -q fha0 '+str(w/'rm10.drm')]
        continue
    if line.startswith(('attach -q dsk','attach -q dtc')):
        f=line.split()
        dst=w/(f[2]+Path(f[3]).suffix)
        shutil.copyfile(f[3],dst)
        line='attach -q '+f[2]+' '+str(dst)
    if line.startswith('attach -q dcs0 '):
        line='attach -q dcs0 '+os.environ['V1973_DCS_PORT']
    if line.startswith('set -q -n log '):
        line='set -q -n log '+str(w/'simh.log')
    lines.append(line)
assert 'set cpu 64k' in lines and 'boot ptr' in lines
(w/'physical.ini').write_text('\n'.join(lines)+'\n')
PY
python3 "$here/host-v1974.py" "$w/pty-run" "$PDP10_PREFIX/bin/pdp10-ka" \
    "$w/physical.ini" "$b/kcore.map" "$w/console.log" "${V1970_TIMEOUT:-600}" "$b"
python3 - "$w" <<'PY'
from pathlib import Path
import sys
w=Path(sys.argv[1])
a,b=[(w/n).read_bytes() for n in ('rm10-before.drm','rm10.drm')]
start=0o4214*128*8
assert len(a)==len(b)==2700*128*8
assert a[:start]==b[:start]
assert a[start:]!=b[start:]
print('PASS RM10 descriptor/reserved region unchanged; physical backing data written')
PY
