#!/bin/sh
# Replay a source-built 48K PDP-6 PURE guest without rebuilding KCORE.
# After a normal simulator HALT, inspect exact MM owner/arena words and
# the typed BRK cause printed by the test-only monitor-UUO veneer.
# Diagnostic only: it does not certify successful RAW reclamation.
set -eu
: "${PURE_BRK_BUILD_V1615:?point to prior pure-brk-pressure-v1614.*/build}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
boot=$PURE_BRK_BUILD_V1615
test -s "$boot/kcore.map"
test -s "$boot/boot.ini"
test -s "$boot/purev1612-mres.dobj"
work=$(mktemp -d "$TMPDIR/pure-brk-replay-v1615.XXXXXX")
trap 'echo "v1615 physical trace: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$boot/boot.ini" "$work/noaux.ini" "$boot" "$work" <<'PY'
from pathlib import Path
import sys
inp,out,old,new=sys.argv[1:]
s=Path(inp).read_text()
for i in range(4):
    matches=[line.split()[-1] for line in s.splitlines()
             if line.startswith('attach -q dtc%d '%i)]
    assert len(matches)==1
    src=Path(matches[0])
    assert src.is_file()
    dst=Path(new)/'media'/('dtc%d.tap'%i)
    dst.write_bytes(src.read_bytes())
    s=s.replace(str(src),str(dst))
s='\n'.join(line for line in s.splitlines()
       if not line.startswith(('attach -q dsk','attach -q dr')))
Path(out).write_text(s+'\n')
PY
port=$((34000 + ($$ % 11500)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/trace.ini" "$port" "$((port+13000))"
python3 - "$boot/kcore.map" "$work/trace.ini" \
    "$boot/kcore.dxr" "$PDP10_PREFIX/bin/dxrcheck" <<'PY'
from pathlib import Path
import re,subprocess,sys,os
sym={}
for line in Path(sys.argv[1]).read_text().splitlines():
    p=line.split()
    if len(p)>=2 and all(c in '01234567' for c in p[1]):
        sym[p[0]]=int(p[1],8)
need=['mm_extents','mm_extent_count','mm_arenas','mm_arena_count',
      'proc_current_slot','proc_high_slot']
assert all(x in sym for x in need)
f=Path(sys.argv[2])
s=f.read_text()
assert 'go 020\nexit\n' in s
tail=''
site=os.environ.get('PURE_BREAK_SITE_V1616','')
trigger=os.environ.get('PURE_CONSOLE_STOP_V1616','')
assert not (site and trigger), 'choose either source or console stop'
return_after=os.environ.get('PURE_BRK_RETURN_V1616','0')=='1'
assert not return_after or trigger, 'BRK return trap needs console stop'
wait_tape=os.environ.get('PURE_TAPE_WAIT_BREAK_V1617','0')=='1'
assert not wait_tape or (trigger and not return_after), \
    'tape search trap needs its own console stop'
if trigger:
    assert re.fullmatch(r'[A-Za-z0-9_+<>\[\]/-]+',trigger), 'unsafe trigger'
    tail+='expect "%s"\n'%trigger
    print('v1616: console EXPECT stop on %s'%trigger)
elif site:
    assert site in sym, 'missing source-mapped breakpoint symbol: '+site
    tail+='break %06o\n'%sym[site]
    tail+='show break\n'
    print('v1616: source-mapped CPU breakpoint %s=%06o'%
          (site,sym[site]))
elif os.environ.get('PURE_OOM_BREAK_V1615','0') == '1':
    raw=subprocess.check_output([sys.argv[4],'-d',sys.argv[3]],text=True)
    words={int(a,8):int(w,8) for a,w in re.findall(
        r'(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$',raw)}
    fatal=sym['proc_fatal_close_current_v879']
    hits=[addr for addr,w in words.items()
          if w==0o201040000001 and
             words.get(addr+1)==(0o254000000000|fatal)]
    assert len(hits)==1, 'expected unique genuine BRK fatal path'
    tail+='break %06o\n'%hits[0]
    tail+='show break\n'
    print('v1615: fatal OOM CPU breakpoint %06o'%hits[0])
tail+='go 020\n'
if return_after:
    raw=subprocess.check_output([sys.argv[4],'-d',sys.argv[3]],text=True)
    words={int(a,8):int(w,8) for a,w in re.findall(
        r'(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$',raw)}
    vm=sym['vm_space_brk_current']
    sites=[addr for addr,word in words.items()
           if word==(0o260740000000|vm)]
    assert len(sites)==1, 'BRK callsite must be unique in fixed KCORE'
    ret=sites[0]+1
    assert (words[ret]&0o777777000000)==0o316040000000
    assert (words[ret+1]&0o777777000000)==0o254000000000
    tail+='break %06o\nshow break\ncont\n'%ret
    (f.parent/'brk-return-site-v1616').write_text('%06o\n'%ret)
    print('v1616: deferred BRK return breakpoint %06o'%ret)
if wait_tape:
    pc=0o30762
    tape=Path(sys.argv[3]).parent/'tape-mres.dxr'
    raw=subprocess.check_output([sys.argv[4],'-d',str(tape)],
                                text=True)
    match=re.search(r'(?m)^IMAGE\s+000331\s+([0-7]{12})$',raw)
    assert match and int(match.group(1),8)==(
        0o336000000000|sym['storage_count']), \
        'tape MRES no longer matches the linked wait instruction'
    tail+='break %06o\nshow break\ncont\n'%pc
    print('v1617: deferred source-checked DECtape wait PC=%06o'%pc)
if return_after or site or os.environ.get('PURE_OOM_BREAK_V1615','0') == '1':
    tail+='examine 1\nexamine 2\n'
if wait_tape:
    assert 'storage_state' in sym and 'storage_count' in sym
    tail+='examine %06o\nexamine %06o\n'%(
        sym['storage_state'],sym['storage_count'])
if os.environ.get('PURE_MRES_PROBE_V1617','0') == '1':
    for name in ('proc_swap_reclaim', 'proc_swap_service_one'):
        assert name in sym, 'missing scheduler service symbol: '+name
        tail+='examine %06o\n'%sym[name]
    tail+='examine 030762\n'
for x in need:
    tail+='examine %06o\n'%sym[x]
tail+='examine %06o-%06o\n'%(sym['mm_arenas'],sym['mm_arenas']+7)
tail+='examine %06o-%06o\n'%(sym['mm_extents'],sym['mm_extents']+95)
tail+='exit\n'
f.write_text(s.replace('go 020\nexit\n',tail,1))
print('v1615: MM extent base %06o, count at %06o'%
      (sym['mm_extents'],sym['mm_extent_count']))
PY
set +e
(
    cd "$boot"
    TERM=dumb timeout -k 3s ${PURE_REPLAY_TIMEOUT_V1615:-240} \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/trace.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
echo "v1615: simulator status=$rc"
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
grep -E 'PURE.*LOADED|\[B|!G|C[0-7]{6}|HALT|^0*[0-7]+:' \
    "$work/trace.clean" | tail -110 || :
echo "v1615: complete trace $work/trace.clean"
python3 "$here/analyze-v1615.py" "$boot/kcore.map" \
    "$work/trace.clean" >"$work/physical-mm.log" 2>&1 || :
cat "$work/physical-mm.log"
if [ -n "${PURE_CONSOLE_STOP_V1616:-}" ]; then
    if [ "${PURE_TAPE_WAIT_BREAK_V1617:-0}" = 1 ]; then
        if ! grep -F 'Breakpoint, PC: 030762 ' \
            "$work/trace.clean" >/dev/null; then
            echo 'v1617: INCONCLUSIVE, tape wait breakpoint not reached'
            exit 1
        fi
        echo 'v1617: physical DECtape search-wait PC captured'
        echo 'v1617: no restoration or BRK completion is claimed'
        exit 0
    fi
    if [ "${PURE_BRK_RETURN_V1616:-0}" = 1 ]; then
        site=$(cat "$work/brk-return-site-v1616")
        if ! grep -F "Breakpoint, PC: $site " "$work/trace.clean" >/dev/null; then
            echo 'v1616: INCONCLUSIVE, deferred BRK return breakpoint not reached'
            exit 1
        fi
        if ! grep -q 'current slot 1' "$work/physical-mm.log"; then
            echo 'v1616: INCONCLUSIVE, requester already cleaned up'
            exit 1
        fi
        echo 'v1616: captured genuine BRK return and pre-cleanup MM owners'
        exit 0
    fi
    if [ "$rc" -eq 124 ] ||
       ! grep -F "${PURE_CONSOLE_STOP_V1616}" "$work/trace.clean" >/dev/null; then
        echo 'v1616: INCONCLUSIVE, console-trigger stop was not reached'
        exit 1
    fi
    echo 'v1616: console-triggered physical MM stop captured'
    exit 0
fi
if [ -n "${PURE_BREAK_SITE_V1616:-}" ] ||
   [ "${PURE_OOM_BREAK_V1615:-0}" = 1 ]; then
    if ! grep -q 'Breakpoint, PC:' "$work/trace.clean"; then
        echo 'v1616: INCONCLUSIVE; source-mapped breakpoint not reached'
        exit 1
    fi
    echo 'v1616: captured source-mapped CPU breakpoint and physical MM state'
    exit 0
fi
if [ "$rc" -eq 124 ]; then
    echo 'v1615: INCONCLUSIVE; timed out before halt/physical snapshot'
    exit 1
fi
if grep -Eq 'C[0-7]{6}F' "$work/trace.clean"; then
    echo 'v1615: captured typed BRK refusal; inspect physical snapshot'
elif grep -Eq '\[A[0-7]{6}/[0-7]{6}\]H' "$work/trace.clean"; then
    echo 'v1615: BRK succeeded and test halted before child cleanup'
else
    echo 'v1615: INCONCLUSIVE; no typed refusal or controlled success HALT'
    echo 'v1615: fatal BRK OOM can terminate the requester before its AC2 veneer runs'
    echo 'v1615: post-cleanup MM extents are not live refusal geometry'
    exit 1
fi
