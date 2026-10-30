#!/bin/sh
# Bounded, non-mutating native PDP-6 scheduler breakpoint diagnostic.
set -eu
: "${DAIMOS_BOOT_V734:?set to a CLEAN PDP-6 boot-image directory}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
src=$DAIMOS_BOOT_V734
work=$(mktemp -d "$TMPDIR/daimos-mm-swap-victim-v734.XXXXXX")
trap 'if [ "${DAIMOS_TRACE_KEEP_V734:-0}" = 1 ]; then echo "trace fixture: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
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
required=('proc_wait_event','proc_runq_remove','proc_sched_tick_select','proc_swap_victim','proc_high_slot','proc_current_slot','proc_table','proc_swap_records','mm_extent_count','proc_sched_cursor','proc_sched_kick','clk_tick_count','proc_runq_head','proc_timer_next')
assert all(x in symbols for x in required), 'missing linked symbol'
s=Path(sys.argv[2]).read_text().split('go 020\n')[0]
s+='break '+symbols['proc_wait_event']+'\n'
s+='go 020\n'
s+='nobreak all\n'
s+='break 014102\n'
s+='go\n'
s+='nobreak all\n'
s+='break 026220\n'
s+='go\n'
s+='examine 026432\n'
s+='nobreak all\n'
s+='break 026221\n'
s+='go\n'
s+='examine 026432\n'

for x in ('proc_high_slot','proc_current_slot','proc_table','proc_swap_records','mm_extent_count','proc_sched_cursor','proc_sched_kick','clk_tick_count','proc_runq_head','proc_timer_next'):
    s+='examine '+symbols[x]+'\n'
s+='examine 026215-026230\nexamine 020135\nexamine 020553\nexamine 034737-034754\nexamine 034060-034070\nexamine 020604-020616\nexamine 1\nexamine 10\nexamine 11\nexamine 12\nexamine 13\nexamine 14\nexamine 17\nexit\n'
Path(sys.argv[3]).write_text(s)
PY
rc=0
(cd "$work/boot" && TERM=dumb timeout -k 2s 65s "$PDP10_PREFIX/bin/pdp6" trace.ini) > "$work/trace.log" 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
    echo "v734: simulator returned $rc (not a passing breakpoint trace)" >&2
    tail -27 "$work/trace.log" >&2
    exit 1
fi
if ! grep -q 'Breakpoint, PC: 014102' "$work/trace.log" || ! grep -q 'Breakpoint, PC: 026221' "$work/trace.log"; then
    tail -40 "$work/trace.log" >&2
    echo 'v734: expected scheduler breakpoint absent; no PASS' >&2
    exit 1
fi
python3 - "$work/trace.log" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text()
values=[int(x,8) for x in re.findall(r'^26432:\s+([0-7]{12})\s*$',s,re.M)]
if len(values)!=2:
    raise SystemExit('v734: expected exactly two active-request samples')
before,after=values
lh_before,rh_before=before>>18,before&0o777777
lh_after,rh_after=after>>18,after&0o777777
if not (lh_before>0 and lh_after==lh_before-1 and rh_before!=0 and rh_before==rh_after):
    raise SystemExit(f'v734: watchdog decrement failed {before:012o} -> {after:012o}')
print(f'v734: native watchdog countdown {lh_before:o}->{lh_after:o}, '
      f'descriptor {rh_before:o} preserved: PASS')
PY
grep -E 'Breakpoint, PC:|^[0-7]{4,7}:|INIT V1' "$work/trace.log" | tail -22
echo 'v734: two consecutive DSK watchdog entry samples captured (not scheduler acceptance)'
