#!/bin/sh
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
test "$#" = 2
b=$(cd "$1" && pwd)
mkdir "$2"
w=$(cd "$2" && pwd)
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -o "$w/pty-run" "$kit/tools/pty-run-v1.c"
# Copy all original disk members; never modify the source build media.
python3 - "$b" "$w" <<'PY'
from pathlib import Path
import sys,shutil,hashlib
b,w=map(Path,sys.argv[1:])
lines=[]
disks=[]
for line in (b/'boot.ini').read_text().splitlines():
    if line=='exit':
        continue
    if line.startswith('attach -q '):
        f=line.split()
        dev=f[2]
        if dev.startswith(('dtc','mtc','dr')):
            continue
        if dev in ('dsk0','dsk1','dsk2','dsk3'):
            dst=w/(dev+'.dsk')
            shutil.copyfile(f[3],dst)
            disks.append(dst)
            line='attach -q '+dev+' '+str(dst)
        elif dev=='-n':
            line='attach -q -n '+f[3]+' '+str(w/(f[3]+'.out'))
    if line.startswith('set -q -n log '):
        line='set -q -n log '+str(w/'simh.log')
    lines.append(line)
assert len(disks)==4 and 'set cpu 64k' in lines
(w/'media-before.sha256').write_text(''.join(
    hashlib.sha256(d.read_bytes()).hexdigest()+'  '+d.name+'\n' for d in disks))
(w/'physical.ini').write_text('\n'.join(lines)+'\n')
PY
port=$((34000 + ($$ % 10000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" "$w/physical.ini" "$w/headless.ini" "$port" "$((port+12000))"
python3 "$here/host-v1958.py" "$w/pty-run" "$PDP10_PREFIX/bin/pdp6" "$w/headless.ini" "$b/kcore.map" "$w/console.log" "${V1955_TIMEOUT:-900}" "$b"
