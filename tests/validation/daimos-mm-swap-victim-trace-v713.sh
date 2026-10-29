#!/bin/sh
# Bounded, non-mutating capture of the first native swap-victim entry.
set -eu
: "${DAIMOS_BOOT_V713:?set to a CLEAN PDP-6 boot-image directory}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
src=$DAIMOS_BOOT_V713
work=$(mktemp -d "$TMPDIR/daimos-mm-swap-victim-v713.XXXXXX")
trap 'if [ "${DAIMOS_TRACE_KEEP_V713:-0}" = 1 ]; then echo "trace fixture: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
mkdir -p "$work/boot"
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$src/disk" > "$work/d6fsck.log" 2>&1 || { cat "$work/d6fsck.log"; exit 1; }
grep -q 'state=CLEAN' "$work/d6fsck.log"
cp -a "$src/disk" "$work/boot/disk"
if [ -d "$src/drum" ]; then cp -a "$src/drum" "$work/boot/drum"; fi
python3 - "$src/boot.ini" "$work/boot/boot.ini" "$src" "$work/boot" <<'PY'
from pathlib import Path
import sys
inp,out,old,new=sys.argv[1:]
s=Path(inp).read_text()
for medium in ('disk','drum'):
    s=s.replace(old+'/'+medium+'/',new+'/'+medium+'/')
s=s.replace(old+'/boot.simh.log',new+'/boot.simh.log')
Path(out).write_text(s)
PY
"$self/../lib/daimos-simh-headless.sh" "$work/boot/boot.ini" "$work/boot/headless.ini" 32913 46913
python3 - "$src/kcore.map" "$work/boot/headless.ini" "$work/boot/trace.ini" <<'PY'
from pathlib import Path
import sys
symbols={}
for line in Path(sys.argv[1]).read_text().splitlines():
    p=line.split()
    if len(p)>1 and all(c in '01234567' for c in p[1]): symbols[p[0]]=p[1]
required=('proc_swap_victim','proc_high_slot','proc_current_slot','proc_table','proc_swap_records','mm_extent_count')
assert all(x in symbols for x in required), 'missing linked symbol'
s=Path(sys.argv[2]).read_text().split('go 020\n')[0]
s+='break '+symbols['proc_swap_victim']+'\n'
s+='go 020\n'
for x in ('proc_high_slot','proc_current_slot','proc_table','proc_swap_records','mm_extent_count'):
    s+='examine '+symbols[x]+'\n'
s+='examine 1\nexamine 10\nexamine 11\nexamine 12\nexamine 13\nexamine 14\nexamine 17\nexit\n'
Path(sys.argv[3]).write_text(s)
PY
rc=0
(cd "$work/boot" && TERM=dumb timeout -k 2s 65s "$PDP10_PREFIX/bin/pdp6" trace.ini) > "$work/trace.log" 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
    echo "v713: simulator returned $rc (not a passing breakpoint trace)" >&2
    tail -27 "$work/trace.log" >&2
    exit 1
fi
if ! grep -q 'Breakpoint, PC:' "$work/trace.log"; then
    tail -40 "$work/trace.log" >&2
    echo 'v713: no swap-victim breakpoint reached; no PASS' >&2
    exit 1
fi
grep -E 'Breakpoint, PC:|^[0-7]{4,7}:|INIT V1' "$work/trace.log" | tail -22
echo 'v713: native first-entry swap-victim trace captured (not scheduler acceptance)'
