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
rbn_found=os.environ.get('PURE_RBN_FOUND_BREAK_V1619','0')=='1'
assert not rbn_found or (trigger and not return_after and not wait_tape), \
    'RBN found/fail trap requires separate console stop'
rbn_transfer=os.environ.get('PURE_RBN_TRANSFER_V1619','0')=='1'
assert not rbn_transfer or rbn_found, \
    'RBN data-completion trap requires a physical matching block'
prefix_boundary=os.environ.get('PURE_PREFIX_BOUNDARY_V1620','0')=='1'
assert not prefix_boundary or (
    trigger and not return_after and not wait_tape and not rbn_found), \
    'PURE boundary trap requires its own late console stop'
prefix_follow=os.environ.get('PURE_PREFIX_FOLLOW_V1620','0')=='1'
assert not prefix_follow or prefix_boundary, \
    'prefix follow requires physical transaction entry breakpoint'
prefix_schedule=os.environ.get('PURE_PREFIX_SCHED_V1620','0')=='1'
assert not prefix_schedule or prefix_follow, \
    'scheduler wake needs completed physical MM retype/unpin watches'
advance_us=os.environ.get('PURE_DTC_ADVANCE_US_V1618','')
assert not advance_us or wait_tape, \
    'timed advancement requires a real tape search breakpoint'
advance_windows=int(os.environ.get('PURE_DTC_WINDOWS_V1618','1'))
assert 1<=advance_windows<=3, 'bounded to three physical timer windows'
if advance_us:
    assert advance_us.isdecimal() and 100000<=int(advance_us)<=10000000, \
        'timed SIMH step must be between 0.1 and 10 seconds'
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
if rbn_found:
    # A v1619 test-only export map establishes these exact labels and
    # verifies binary identity with the production v1618 tape module.
    path=Path(os.environ['PURE_RBN_MAP_V1619'])
    local={}
    for line in path.read_text().splitlines():
        p=line.split()
        if len(p)>=2 and p[1] and not p[1].strip('01234567'):
            local[p[0]]=int(p[1],8)
    assert local['dtc_search_pi_found']==0o415
    assert local['dtc_search_fail']==0o463
    if rbn_transfer:
        assert local['dtc_search_pi_read']==0o455
        assert local['tape_dct_done_keep_dtc']==0o124
    tape_base=0o30431
    found_pc=tape_base+local['dtc_search_pi_found']
    fail_pc=tape_base+local['dtc_search_fail']
    tail+='break %06o\nbreak %06o\nshow break\ncont\n'%(
        found_pc,fail_pc)
    print('v1619: deferred RBN match %06o or failure %06o'%(
        found_pc,fail_pc))
    if rbn_transfer:
        read_pc=tape_base+local['dtc_search_pi_read']
        done_pc=tape_base+local['tape_dct_done_keep_dtc']
        # Snapshot the first block match before leaving PI3; then follow
        # its original read-arming branch and DCT read completion.
        tail+='examine %06o\nexamine %06o\n'%(
            sym['storage_state'],0o31245)
        tail+='nobreak %06o\nbreak %06o\ncont\n'%(
            found_pc,read_pc)
        tail+='examine %06o\nexamine %06o\n'%(
            sym['storage_state'],0o31245)
        tail+='nobreak %06o\nbreak %06o\ncont\n'%(
            read_pc,done_pc)
        tail+='examine %06o\nexamine %06o\nexamine %06o\n'%(
            sym['storage_state'],sym['storage_count'],0o31246)
        print('v1619: follow PI3 read %06o and DCT completion %06o'%(
            read_pc,done_pc))
if prefix_boundary:
    pure=Path(sys.argv[3]).parent/'pure-mres-v1612.dxr'
    linked=Path(sys.argv[3]).parent/'pure-mres-v1612.map'
    offsets={}
    for line in linked.read_text().splitlines():
        p=line.split()
        if len(p)>=2 and not p[1].strip('01234567'):
            offsets[p[0]]=int(p[1],8)
    assert offsets['mm_pure_release_prefix_v1384']==0o2563
    assert offsets['mm_pure_commit_prefix_v1384']==0o2565
    raw=subprocess.check_output([sys.argv[4],'-d',str(pure)],text=True)
    image={int(a,8):int(w,8) for a,w in re.findall(
        r'(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$',raw)}
    assert image[0o2563]==0o201000000001
    assert image[0o2565]==0o201000000002
    base=0o32027
    rollback=base+offsets['mm_pure_release_prefix_v1384']
    commit=base+offsets['mm_pure_commit_prefix_v1384']
    assert (rollback,commit)==(0o34612,0o34614)
    tail+='break %06o\nbreak %06o\nshow break\ncont\n'%(
        rollback,commit)
    print('v1620: exact linked PURE rollback %06o / commit %06o'%(
        rollback,commit))
    if prefix_follow:
        # In this preserved 48K image the live slot-2 descriptor is
        # extent index 13: mm_extents + 2*13 + 1 = 024307.
        # Watch machine-memory writes, not a guessed C return.
        owner_meta=sym['mm_extents']+2*13+1
        assert owner_meta==0o24307
        tail+='examine %06o\n'%owner_meta
        tail+='nobreak %06o\nnobreak %06o\n'%(rollback,commit)
        tail+='break -W %06o\nshow break\ncont\n'%owner_meta
        tail+='examine %06o\n'%owner_meta
        tail+='cont\nexamine %06o\n'%owner_meta
        print('v1620: physical MM descriptor write-watches %06o'%owner_meta)
        if prefix_schedule:
            cursor=sym['proc_sched_cursor']
            current=sym['proc_current_slot']
            assert (cursor,current)==(0o24235,0o24233)
            tail+='nobreak -W %06o\n'%owner_meta
            tail+='break -W %06o\nshow break\ncont\n'%cursor
            tail+='examine %06o\nexamine %06o\n'%(
                cursor,owner_meta)
            tail+='nobreak -W %06o\n'%cursor
            tail+='break -W %06o\nshow break\ncont\n'%current
            tail+='examine %06o\nexamine %06o\n'%(
                current,owner_meta)
            print('v1620: physical scheduler write-watches cursor=%06o current=%06o'%(
                cursor,current))
if return_after or site or os.environ.get('PURE_OOM_BREAK_V1615','0') == '1':
    tail+='examine 1\nexamine 2\n'
if wait_tape:
    assert 'storage_state' in sym and 'storage_count' in sym
    tail+='examine %06o\nexamine %06o\n'%(
        sym['storage_state'],sym['storage_count'])
    if advance_us:
        assert 'clk_tick_count' in sym
        # Physical native tape BSS is immediately after the original
        # DXR image. The v1618 auditor proves that image has the
        # expected original size before interpreting these cells.
        tail+='examine %06o\nexamine %06o-%06o\n'%(
            sym['clk_tick_count'],0o31240,0o31245)
        tail+='nobreak 030762\n'
        for _ in range(advance_windows):
            tail+='step -t %d\n'%int(advance_us)
            tail+='examine %06o\nexamine %06o\nexamine %06o\n'%(
                sym['storage_state'],sym['storage_count'],
                sym['clk_tick_count'])
            tail+='examine %06o-%06o\n'%(0o31240,0o31245)
if rbn_found:
    assert 'clk_tick_count' in sym
    tail+='examine %06o\nexamine %06o\nexamine %06o\n'%(
        sym['storage_state'],sym['storage_count'],sym['clk_tick_count'])
    tail+='examine %06o-%06o\n'%(0o31240,0o31246)
if prefix_boundary:
    for reg in (1,2,3,4):
        tail+='examine %o\n'%reg
    for name in ('proc_sched_cursor','proc_current_slot',
                 'proc_high_slot','mm_extent_count'):
        assert name in sym, 'missing linked kernel source symbol '+name
        tail+='examine %06o\n'%sym[name]
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
    if [ "${PURE_PREFIX_BOUNDARY_V1620:-0}" = 1 ]; then
        if [ "${PURE_PREFIX_FOLLOW_V1620:-0}" = 1 ]; then
            if ! grep -F 'Breakpoint, PC: 034614 ' \
                "$work/trace.clean" >/dev/null; then
                echo 'v1620: INCONCLUSIVE; exact commit entry absent'
                exit 1
            fi
            if [ "$(grep -c 'Breakpoint, PC:' "$work/trace.clean")" -lt 3 ]; then
                echo 'v1620: INCONCLUSIVE; MM type/pin watchpoint incomplete'
                exit 1
            fi
            if [ "${PURE_PREFIX_SCHED_V1620:-0}" = 1 ]; then
                if [ "$(grep -c 'Breakpoint, PC:' "$work/trace.clean")" -lt 5 ]; then
                    echo 'v1620: INCONCLUSIVE; READY/current slot watches incomplete'
                    exit 1
                fi
                echo 'v1620: physical MM retype/unpin and scheduler writes sampled'
            else
                echo 'v1620: physical commit + two descriptor-write events sampled'
            fi
            echo 'v1620: inspect MM owner mode and pin values before acceptance'
            exit 0
        fi
        if grep -F 'Breakpoint, PC: 034614 ' \
            "$work/trace.clean" >/dev/null; then
            echo 'v1620: REAL prefix COMMIT entry reached; execution not yet proven'
            exit 0
        fi
        if grep -F 'Breakpoint, PC: 034612 ' \
            "$work/trace.clean" >/dev/null; then
            echo 'v1620: REAL prefix ROLLBACK entry reached; outcome open'
            exit 0
        fi
        echo 'v1620: INCONCLUSIVE; neither PURE MM boundary reached'
        exit 1
    fi
    if [ "${PURE_RBN_FOUND_BREAK_V1619:-0}" = 1 ]; then
        if [ "${PURE_RBN_TRANSFER_V1619:-0}" = 1 ]; then
            for pc in 031046 031106 030555; do
                if ! grep -F "Breakpoint, PC: $pc " \
                    "$work/trace.clean" >/dev/null; then
                    echo "v1619: INCONCLUSIVE; physical PI3/PI5 stage $pc missing"
                    exit 1
                fi
            done
            echo 'v1619: physical RBN 4 match, read command and DCT done'
            echo 'v1619: VFS/slot-0 MM restore completion remains OPEN'
            exit 0
        fi
        if grep -F 'Breakpoint, PC: 031046 ' \
            "$work/trace.clean" >/dev/null; then
            echo 'v1619: physically matched DECtape RBN; READ not yet committed'
            exit 0
        fi
        if grep -F 'Breakpoint, PC: 031114 ' \
            "$work/trace.clean" >/dev/null; then
            echo 'v1619: physically reached DECtape RBN search failure'
            exit 0
        fi
        echo 'v1619: INCONCLUSIVE; no RBN match or failure by timeout'
        exit 1
    fi
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
