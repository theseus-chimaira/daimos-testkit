#!/bin/sh
# v907: full PDP-6 HUP partial commit with real pinned u-area MM owner.
# Only an isolated kernel copy contains injection and observability.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
pipe_hup=${DAIMOS_V1104_PIPE_HUP:-0}
case "$pipe_hup" in 0|1) ;; *) echo 'v1104: invalid PIPE/HUP mode' >&2; exit 2 ;; esac
if [ "$pipe_hup" = 1 ]; then
    work=$(mktemp -d "$TMPDIR/daimos-session-hup-pipe-mm-v1104.XXXXXX")
else
    work=$(mktemp -d "$TMPDIR/daimos-session-hup-physical-v907.XXXXXX")
fi
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel/proc/proc_pdp6.s" \
    "${DAIMOS_V907_NEGATIVE:-0}" "$pipe_hup" <<'PY'
from pathlib import Path
import sys
path=Path(sys.argv[1]); source=path.read_text()
def patch(old,new):
    global source
    if source.count(old)!=1:
        raise SystemExit('v907: injection anchor not unique: '+repr(old))
    source=source.replace(old,new)
# The first child to receive HUP is really pinned in the kernel MM table.
# The second child first rejects HUP (synthetic v907, physical PIPE MM
# refusal v1104). Retry must skip the finalized first child and deliver
# only the previously refused member HUP.
patch('''        move    1,011
        movei   2,2                    ; default-fatal HUP
        pushj   17,proc_event_apply
        jumpn   1,proc_session_teardown_fail''','''        skipn   daimos_test_first_v907
        jrst    daimos_test_pin_first_v907
        move    6,daimos_test_first_v907
        camn    6,011
        jrst    daimos_test_repeat_v907
        skipn   daimos_test_failures_v907
        jrst    daimos_test_fail_second_v907
        aos     daimos_test_second_v907
        jrst    daimos_test_deliver_v907
daimos_test_pin_first_v907:
        movem   011,daimos_test_first_v907
        movem   010,daimos_test_leader_v907
        hlrz    1,(012)               ; real first-member u-area base
        movem   1,daimos_test_base_v907
        pushj   17,mm_pin
        jumpe   1,daimos_test_pin_ok_v907
        aos     daimos_test_errors_v907
        jrst    daimos_test_deliver_v907
daimos_test_pin_ok_v907:
        aos     daimos_test_pins_v907
        jrst    daimos_test_deliver_v907
daimos_test_repeat_v907:
        aos     daimos_test_repeats_v907
        jrst    daimos_test_deliver_v907
daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        jrst    proc_session_teardown_fail
daimos_test_deliver_v907:
        move    1,011
        movei   2,2                    ; default-fatal HUP
        pushj   17,proc_event_apply
        jumpn   1,proc_session_teardown_fail''')
patch('''proc_session_teardown_commit_v875:
        ; No member can have an unclosed FD after successful HUP.''','''proc_session_teardown_commit_v875:
        skipn   daimos_test_first_v907
        jrst    daimos_test_commit_done_v907
        move    4,daimos_test_leader_v907
        came    4,010                  ; only the targeted session leader
        jrst    daimos_test_commit_done_v907
        ; At the actual final commit, prove the first HUP remains an
        ; irrevocably finalized, physically pinned MM owner.
        move    4,daimos_test_first_v907
        imuli   4,PROC_WORDS
        add     4,proc_table
        move    6,(4)
        trnn    6,PROC_TRANSITION_RH
        aos     daimos_test_errors_v907
        move    6,1(4)
        camn    6,[-1]
        jrst    daimos_test_vm_none_v907
        aos     daimos_test_errors_v907
daimos_test_vm_none_v907:
        hlrz    4,(4)
        move    6,PROC_FINALIZE_OFFSET(4)
        tlne    6,PROC_FINALIZE_MARK_LH
        jrst    daimos_test_pending_check_v907
        aos     daimos_test_errors_v907
daimos_test_pending_check_v907:
        aos     daimos_test_pending_v907
        move    1,daimos_test_base_v907
        pushj   17,mm_unpin
        jumpe   1,daimos_test_unpin_ok_v907
        aos     daimos_test_errors_v907
        jrst    daimos_test_commit_done_v907
daimos_test_unpin_ok_v907:
        aos     daimos_test_unpins_v907
daimos_test_commit_done_v907:
        ; No member can have an unclosed FD after successful HUP.''')
if sys.argv[3] == '1':
    # Do not synthesize the second HUP error: its real FILE close now
    # reaches a genuinely pinned private PIPE extent and fails -5.
    # Keep the v907 first-member pinned-uarea and committed-HUP checks.
    patch('''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        jrst    proc_session_teardown_fail''',
          '''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        setom   daimos_test_pipe_armed_v1104
        jrst    daimos_test_deliver_v907''')
# Negative control restores pre-v905 handling in this isolated image.
if sys.argv[2]=='1':
    old='''        ; A previous HUP may have committed its fatal exit but deferred
        ; u-area MM release.'''
    start=source.index(old)
    end=source.index('proc_session_teardown_deliver_v905:\n',start)
    source=source[:start]+source[end+len('proc_session_teardown_deliver_v905:\n'):]
source+='''
        .globl mm_pin
        .globl mm_unpin
        .bss
        .globl daimos_test_first_v907
daimos_test_first_v907: .block 1
        .globl daimos_test_leader_v907
daimos_test_leader_v907: .block 1
        .globl daimos_test_base_v907
daimos_test_base_v907: .block 1
        .globl daimos_test_pins_v907
daimos_test_pins_v907: .block 1
        .globl daimos_test_unpins_v907
daimos_test_unpins_v907: .block 1
        .globl daimos_test_failures_v907
daimos_test_failures_v907: .block 1
        .globl daimos_test_second_v907
daimos_test_second_v907: .block 1
        .globl daimos_test_repeats_v907
daimos_test_repeats_v907: .block 1
        .globl daimos_test_pending_v907
daimos_test_pending_v907: .block 1
        .globl daimos_test_errors_v907
daimos_test_errors_v907: .block 1
'''
path.write_text(source)
PY
if [ "$pipe_hup" = 1 ]; then
    python3 - "$work/source/system/kernel/mm/mm_pdp6.s" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
def patch(before, after):
    global source
    assert source.count(before) == 1, 'v1104: MM hook anchor drift: '+repr(before)
    source = source.replace(before, after, 1)

# Only the second session member's final private PIPE close is armed.
# Pin the *actual* physical MM extent on its first free. The second
# attempt unpins and lets production MM ownership validation free it.
# The same first owner/address and original 0,,1 writer reference must
# survive the refusal; a second attempt may not free a different PIPE.
patch('''mm_free:
        move    5,1
        move    6,2
        move    7,3''', '''mm_free:
        caie    2,3                    ; MM_TYPE_KERNEL_DYNAMIC
        jrst    mm_free_original_v1104
        caie    3,5                    ; PIPE_MM_OWNER
        jrst    mm_free_original_v1104
        skipn   daimos_test_pipe_armed_v1104
        jrst    mm_free_original_v1104
        skipn   daimos_test_pipe_target_v1104
        movem   1,daimos_test_pipe_target_v1104
        move    4,daimos_test_pipe_target_v1104
        came    1,4
        jrst    mm_free_original_v1104
        move    4,3(1)                 ; last writer still owns reference
        caie    4,1
        aos     daimos_test_pipe_errors_v1104
        aos     daimos_test_pipe_calls_v1104
        move    4,daimos_test_pipe_calls_v1104
        caie    4,1
        jrst    daimos_test_pipe_unpin_v1104
        push    17,1
        push    17,2
        push    17,3
        pushj   17,mm_pin
        jumpe   1,daimos_test_pipe_pin_ok_v1104
        aos     daimos_test_pipe_errors_v1104
        jrst    daimos_test_pipe_restore_v1104
daimos_test_pipe_pin_ok_v1104:
        aos     daimos_test_pipe_pins_v1104
        jrst    daimos_test_pipe_restore_v1104
daimos_test_pipe_unpin_v1104:
        push    17,1
        push    17,2
        push    17,3
        pushj   17,mm_unpin
        jumpe   1,daimos_test_pipe_unpin_ok_v1104
        aos     daimos_test_pipe_errors_v1104
        jrst    daimos_test_pipe_restore_v1104
daimos_test_pipe_unpin_ok_v1104:
        aos     daimos_test_pipe_unpins_v1104
daimos_test_pipe_restore_v1104:
        pop     17,3
        pop     17,2
        pop     17,1
mm_free_original_v1104:
        move    5,1
        move    6,2
        move    7,3''')
patch('''mm_free_busy:
        movni   1,5''', '''mm_free_busy:
        move    4,daimos_test_pipe_target_v1104
        camn    4,5
        aos     daimos_test_pipe_busy_v1104
        movni   1,5''')
patch('''        pushj   17,mm_delete
        setz    1,
        popj    17,
mm_free_inval:''', '''        move    4,daimos_test_pipe_target_v1104
        camn    4,5
        aos     daimos_test_pipe_frees_v1104
        pushj   17,mm_delete
        setz    1,
        popj    17,
mm_free_inval:''')
source += '''
        .bss
        .globl daimos_test_pipe_armed_v1104
daimos_test_pipe_armed_v1104: .block 1
        .globl daimos_test_pipe_target_v1104
daimos_test_pipe_target_v1104: .block 1
        .globl daimos_test_pipe_calls_v1104
daimos_test_pipe_calls_v1104: .block 1
        .globl daimos_test_pipe_pins_v1104
daimos_test_pipe_pins_v1104: .block 1
        .globl daimos_test_pipe_unpins_v1104
daimos_test_pipe_unpins_v1104: .block 1
        .globl daimos_test_pipe_busy_v1104
daimos_test_pipe_busy_v1104: .block 1
        .globl daimos_test_pipe_frees_v1104
daimos_test_pipe_frees_v1104: .block 1
        .globl daimos_test_pipe_errors_v1104
daimos_test_pipe_errors_v1104: .block 1
'''
path.write_text(source)
PY
fi
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
incs=""
for d in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
if [ "$pipe_hup" = 1 ]; then
    cflags='-DDAIMOS_V1104_PIPE_HUP=1'
else
    cflags=''
fi
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $cflags $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-session-hup-physical-v907.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"

build="$work/build/system/boot/pdp6"
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    >"$work/build.log" 2>&1 || {
        tail -80 "$work/build.log" >&2
        echo 'v907: isolated image build failed' >&2
        exit 1
    }
for name in first leader base pins unpins failures second repeats pending errors; do
    sym="daimos_test_${name}_v907"
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v907: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
if [ "$pipe_hup" = 1 ]; then
    for name in armed target calls pins unpins busy frees errors; do
        sym="daimos_test_pipe_${name}_v1104"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1104: missing $sym" >&2; exit 1; }
        printf 'pipe_%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
boot="$build/boot.ini"
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' "$boot"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$boot"
done < "$work/addresses"
printf 'exit\n' >> "$boot"
set +e
(cd "$build"; TERM=dumb timeout -k 2s 80s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -85 "$work/simh.out" >&2
    echo "v907: simulator exited $rc" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" "$pipe_hup" <<'PY'
from pathlib import Path
import re
import sys
output=Path(sys.argv[2]).read_text(errors='replace')
seen={}
for line in Path(sys.argv[1]).read_text().splitlines():
    name,addr=line.split()
    values=re.findall(r'(?im)^\s*0*'+re.escape(addr.lstrip('0'))+
                      r'\s*:\s*([0-7]+)\b',output)
    if not values:
        raise SystemExit('v907: missing sample '+name+'\n'+output[-1500:])
    seen[name]=int(values[-1],8)
expected=dict(pins=1,unpins=1,failures=1,second=1,
              repeats=0,pending=1,errors=0)
for name,value in expected.items():
    if seen[name]!=value:
        raise SystemExit('v907: '+name+'='+str(seen[name])+
                         ' expected '+str(value)+'\n'+output[-1800:])
if sys.argv[3] == '1':
    for name, value in dict(pipe_armed=(1 << 36)-1,
                            pipe_calls=2,pipe_pins=1,pipe_unpins=1,
                            pipe_busy=1,pipe_frees=1,pipe_errors=0).items():
        if seen[name] != value:
            raise SystemExit('v1104: '+name+'='+str(seen[name])+
                             ' expected '+str(value)+'\n'+output[-1800:])
    if not seen['pipe_target']:
        raise SystemExit('v1104: no private PIPE owner recorded')
if seen['first']<=2 or seen['leader']<=1 or not seen['base'] or \
        '<' not in output or \
        'H' not in output or 'HALT' not in output or '!' in output:
    raise SystemExit('v907: guest failed\n'+output[-2000:])
if sys.argv[3] == '1':
    print('v1104: booted physical HUP plus PIPE MM_BUSY and pinned '
          'member u-area, exact retries/TTY handoff PASS:',seen)
else:
    print('v907: PDP-6 real MM pin/partial HUP/retry/unpin/TTY handoff PASS:',seen)
PY
