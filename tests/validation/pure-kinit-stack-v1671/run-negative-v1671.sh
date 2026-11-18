#!/bin/sh
# Execute corruptions against an original physical stack/watermark trace.
# A broken measurement must not be mistaken for a safe stack reserve.
set -eu
if [ "$#" -ne 2 ]; then
    echo "usage: $0 PHYSICAL_EVIDENCE_DIR STRICT_BUILD_DIR" >&2
    exit 2
fi
work=$1
build=$2
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
test -s "$work/strict-48-console.clean"
test -s "$work/strict-48-report.json"
test -s "$build/kinit.map"
test -s "$build/kcore.map"

python3 - "$work" "$build" <<'PY'
import json
import re
import sys
from pathlib import Path

work,build=map(Path,sys.argv[1:])
log=(work/'strict-48-console.clean').read_text(encoding='ascii')
kinit=(build/'kinit.map').read_text(encoding='ascii')
kcore=(build/'kcore.map').read_text(encoding='ascii')


def addr(source,name):
    matches=re.findall('^'+name+r'\s+([0-7]+)\s*$',source,re.M)
    if len(matches)!=1:
        raise SystemExit('v1671 mutation source link drift: '+name)
    return int(matches[0],8)


terminal=addr(kinit,'vm_enter_initial_user')
begin=addr(kinit,'kinit_stack_watermark_begin')
water=addr(kcore,'kinit_stack_highwater')
end=addr(kinit,'__kinit_image_end')+255
terminal_tag=r'^Breakpoint, PC:\s+0*%o\b.*$' % terminal
terminal_marker=re.search(terminal_tag,log,re.M)
parts=re.split(terminal_tag,log,maxsplit=1,flags=re.M)
if terminal_marker is None or len(parts)!=2:
    raise SystemExit('v1671 missing terminal mutation anchor')
terminal_prefix=parts[0]+terminal_marker.group(0)+'\n'

def cell(address):
    marker=r'^0*%o:\s+([0-7]{12})\s*$' % address
    match=re.findall(marker,parts[1],re.M)
    if len(match)!=1:
        raise SystemExit('v1671 missing stack mutation address %o'%address)
    return marker,int(match[0],8)


marker,current=cell(water)
report=json.loads((work/'strict-48-report.json').read_text(encoding='ascii'))
if current != report['stored_highwater_offset'] or not 0<current<255:
    raise SystemExit('v1671 expected source-built 48K watermark drift')
bad=re.sub(marker,'%o:\t%012o'%(water,current+1),parts[1],count=1,
           flags=re.M)
(work/'unsafe-counter.log').write_text(terminal_prefix+bad,
                                      encoding='ascii')

marker,current=cell(end)
if current!=int('525252525252',8):
    raise SystemExit('v1671 expected physical upper sentinel drift')
bad=re.sub(marker,'%o:\t%012o'%(end,current-1),parts[1],count=1,
           flags=re.M)
(work/'unsafe-top-word.log').write_text(terminal_prefix+bad,
                                       encoding='ascii')

begin_pattern=r'^Breakpoint, PC:\s+0*%o\b.*\n' % begin
if len(re.findall(begin_pattern,log,re.M))!=1:
    raise SystemExit('v1671 missing single watermark init event')
(work/'unsafe-no-initialize.log').write_text(
    re.sub(begin_pattern,'',log,count=1,flags=re.M),encoding='ascii')

report['stored_highwater_offset']+=1
(work/'unsafe-reported-offset.json').write_text(
    json.dumps(report),encoding='ascii')
PY

for mutant in unsafe-counter unsafe-top-word unsafe-no-initialize; do
    if python3 "$here/measure-v1671.py" "$build/kinit.map" \
        "$build/kcore.map" "$work/$mutant.log" 48 \
        "$work/$mutant-observed.json" > "$work/$mutant-refusal.log" 2>&1; then
        echo "FAIL v1671: $mutant escaped physical stack proof" >&2
        exit 1
    fi
    grep -q '^FAIL v1671 physical KINIT stack:' \
        "$work/$mutant-refusal.log" || {
        cat "$work/$mutant-refusal.log" >&2; exit 1;
    }
    echo "v1671: executed $mutant physical corruption rejected"
done
if python3 "$here/compare-v1671.py" \
    "$work/general-48-report.json" "$work/unsafe-reported-offset.json" \
    "$work/general-64-report.json" "$work/strict-64-report.json" \
    > "$work/unsafe-reported-offset-refusal.log" 2>&1; then
    echo 'FAIL v1671: forged report passed source-matched comparison' >&2
    exit 1
fi
grep -q '^FAIL v1671 stack comparison:' \
    "$work/unsafe-reported-offset-refusal.log" || {
    cat "$work/unsafe-reported-offset-refusal.log" >&2; exit 1;
}
echo 'v1671: forged diagnostic stack summary rejected'
