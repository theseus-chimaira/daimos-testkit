#!/bin/sh
# Diagnostic regression (currently failing): full-system PDP-6 deferred TERM
# followed by descendant EXIT/CHLD WITHOUT an artificially stalled provider.
# Preserve work with KEEP_TEST=1 for failure analysis.
# All fault hooks and witnesses are confined to a disposable kernel copy.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-child-provider-handoff-v934.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
printf 'v924: isolated work %s\n' "$work"
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
def patch(rel, old, new):
    path = root / rel
    source = path.read_text()
    if source.count(old) != 1:
        raise SystemExit('v924: nonunique kernel injection anchor ' + rel)
    path.write_text(source.replace(old, new, 1))

# The FS serialized gateway is a real production code path; the test
# suspends slot 3 after it acquires the genuine lease, before dispatch.
patch('fs/fs_mres.s',
      '''        sub     17,kconst_7_7
        ; The missing-service trampoline already returns -1 normally.''',
      '''        sub     17,kconst_7_7
        move    0,proc_current_slot
        caie    0,3                   ; child H, slot 3 only
        jrst    daimos_test_fs_normal_v924
        skipn   daimos_test_armed_v924
        jrst    daimos_test_fs_normal_v924
        aos     daimos_test_enter_v924
        move    0,fs_provider_ready
        movem   0,daimos_test_held_lease_v924
        hlrz    0,fs_provider_ready
        caie    0,4                   ; slot 3 + 1
        setom   daimos_test_error_v924
        ; Suspend on a private, never-signaled event with lease held.
        ; There is no forced unlock, timeout, or provider transaction.
daimos_test_hold_loop_v924:
        movei   1,daimos_test_hold_event_v924
        pushj   17,proc_wait_event
        jrst    daimos_test_hold_loop_v924
daimos_test_fs_normal_v924:
        ; The missing-service trampoline already returns -1 normally.''')
patch('fs/fs_mres.s',
      '''fs_provider_lock_sleep_v915:
        movei   1,fs_provider_wait_event_v917''',
      '''fs_provider_lock_sleep_v915:
        move    0,proc_current_slot
        caie    0,4                   ; child W, slot 4 only
        jrst    daimos_test_wait_other_v924
        skipn   daimos_test_armed_v924
        jrst    daimos_test_wait_other_v924
        aos     daimos_test_wait_v924
        move    0,fs_provider_ready
        movem   0,daimos_test_wait_lease_v924
        hlrz    0,fs_provider_ready
        caie    0,4
        setom   daimos_test_error_v924
daimos_test_wait_other_v924:
        movei   1,fs_provider_wait_event_v917''')
p = root / 'fs/fs_mres.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_armed_v924
daimos_test_armed_v924: .block 1
        .globl daimos_test_enter_v924
daimos_test_enter_v924: .block 1
        .globl daimos_test_wait_v924
daimos_test_wait_v924: .block 1
        .globl daimos_test_held_lease_v924
daimos_test_held_lease_v924: .block 1
        .globl daimos_test_wait_lease_v924
daimos_test_wait_lease_v924: .block 1
        .globl daimos_test_final_lease_v924
daimos_test_final_lease_v924: .block 1
        .globl daimos_test_hold_event_v924
daimos_test_hold_event_v924: .block 1
        .globl daimos_test_bystander_v924
daimos_test_bystander_v924: .block 1
        .globl daimos_test_error_v924
daimos_test_error_v924: .block 1
''')
# Arm only after INIT launches all four initial child processes.
# An unrelated running child proves scheduler progress during both waits.
patch('proc/proc_pdp6.s',
      '''proc_sleep_ticks:
        hrrz    1,1''',
      '''proc_sleep_ticks:
        move    4,proc_current_slot
        caie    4,1
        jrst    daimos_test_sleep_other_v924
        setom   daimos_test_armed_v924
daimos_test_sleep_other_v924:
        caie    4,2
        jrst    daimos_test_sleep_normal_v924
        skipn   daimos_test_enter_v924
        jrst    daimos_test_sleep_normal_v924
        skipn   daimos_test_wait_v924
        jrst    daimos_test_sleep_normal_v924
        aos     daimos_test_bystander_v924
daimos_test_sleep_normal_v924:
        hrrz    1,1''')
# Count real fatal-event refusal for suspended provider continuations.
patch('proc/proc_pdp6.s',
      '''        move    1,2(012)
        tlne    1,PROC_WAIT_LH_MASK
        jrst    proc_event_fatal_other_defer_term_v926''',
      '''        move    1,2(012)
        tlne    1,PROC_WAIT_LH_MASK
        jrst    daimos_test_fatal_refused_v924
        jrst    daimos_test_fatal_normal_v924
daimos_test_fatal_refused_v924:
        aos     daimos_test_fatal_count_v924
        move    0,2(012)
        and     0,[060000,,0]
        camn    0,[040000,,0]         ; exactly WAIT_CHILD, not INTR
        aos     daimos_test_child_refused_v924
        jrst    proc_event_fatal_other_defer_term_v926
daimos_test_fatal_normal_v924:''')
# Locate slot-6 process finalization and the failure branch. The exiting
# current slot is cleared by proc_exit_finish before this entry, so inspect
# the slot argument rather than proc_current_slot.
patch('proc/proc_pdp6.s',
      """proc_finish_common_v932:
        add     17,kconst_7_7""",
      """proc_finish_common_v932:
        caie    1,6
        jrst    daimos_test_finish_other_v931
        aos     daimos_test_finish_v931
daimos_test_finish_other_v931:
        add     17,kconst_7_7""")
patch('proc/proc_pdp6.s',
      """proc_finish_fail:
        seto    1,""",
      """proc_finish_fail:
        move    0,10
        caie    0,6
        jrst    daimos_test_fail_other_v931
        aos     daimos_test_fail_v931
daimos_test_fail_other_v931:
        seto    1,""")
p = root / 'proc/proc_pdp6.s'
p.write_text(p.read_text() + """
        .bss
        .globl daimos_test_finish_v931
daimos_test_finish_v931: .block 1
        .globl daimos_test_fail_v931
daimos_test_fail_v931: .block 1
""")
# Stage witnesses reside only in the disposable kernel.
patch('proc/proc_pdp6.s',
      '''proc_notify_parent:
        jumpe   1,proc_notify_parent_done''',
      '''proc_notify_parent:
        caie    1,5
        jrst    daimos_test_notify_other_v929
        aos     daimos_test_chld_v929
daimos_test_notify_other_v929:
        jumpe   1,proc_notify_parent_done''')
p = root / 'proc/proc_pdp6.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_chld_v929
daimos_test_chld_v929: .block 1
''')
patch('proc/mach_user_pdp6.s',
      '''proc_deferred_term_check_v926:
        push 17,2''',
      '''proc_deferred_term_check_v926:
        push 17,2
        move 2,proc_current_slot
        caie 2,5
        jrst daimos_test_owner_other_v929
        aos daimos_test_owner_v929
daimos_test_owner_other_v929:
        pop 17,2
        push 17,2''')
p = root / 'proc/mach_user_pdp6.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_owner_v929
daimos_test_owner_v929: .block 1
''')
p = root / 'proc/proc_pdp6.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_fatal_count_v924
daimos_test_fatal_count_v924: .block 1
        .globl daimos_test_child_refused_v924
daimos_test_child_refused_v924: .block 1
''')
patch('proc/proc_pdp6.s',
      '''proc_exit_current:
        move    3,1''',
      '''proc_exit_current:
        move    4,proc_current_slot
        caie    4,6
        jrst    daimos_test_exit_not6_v930
        aos     daimos_test_exit_v930
daimos_test_exit_not6_v930:
        move    4,proc_current_slot
        caie    4,1
        jrst    daimos_test_exit_other_v924
        move    4,fs_provider_ready
        movem   4,daimos_test_final_lease_v924
        halt
        jrst    .-1
daimos_test_exit_other_v924:
        move    3,1''')
p = root / 'proc/proc_pdp6.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_exit_v930
daimos_test_exit_v930: .block 1
''')
PY
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
"$cc" -std=c89 -Os $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-child-provider-handoff-v934.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
build="$work/build/system/boot/pdp6"
printf 'v924: assembling disposable 256K PDP-6 image\n'
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    >"$work/build.log" 2>&1 || {
        tail -90 "$work/build.log" >&2
        echo "v924: image build failed: $work" >&2
        exit 1
    }
for name in chld owner exit finish fail armed enter wait held_lease wait_lease final_lease \
    hold_event bystander error; do
    case "$name" in
        chld|owner) sym="daimos_test_${name}_v929" ;;
        exit) sym="daimos_test_exit_v930" ;;
        finish|fail) sym="daimos_test_${name}_v931" ;;
        *) sym="daimos_test_${name}_v924" ;;
    esac
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v924: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
sym=daimos_test_fatal_count_v924
addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
test -n "$addr" || { echo "v924: missing fatal counter" >&2; exit 1; }
printf '%s %s\n' fatal_count "$addr" >> "$work/addresses"
sym=daimos_test_child_refused_v924
addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
test -n "$addr" || { echo "v924: missing child refusal counter" >&2; exit 1; }
printf '%s %s\n' child_refused "$addr" >> "$work/addresses"
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' \
    "$build/boot.ini"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$build/boot.ini"
done < "$work/addresses"
printf 'exit\n' >> "$build/boot.ini"
printf 'v934: held FS owner/waiter, CHLD/TERM owner handoff\n'
set +e
(cd "$build"; TERM=dumb timeout -k 2s 90s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -90 "$work/simh.out" >&2
    echo "v924: simulator failed ($rc): $work" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" <<'PY'
from pathlib import Path
import re
import sys
out = Path(sys.argv[2]).read_text(errors='replace')
seen = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    name, addr = line.split()
    values = re.findall(r'(?im)^\s*0*' + re.escape(addr.lstrip('0')) +
                        r'\s*:\s*([0-7]+)\b', out)
    if not values:
        raise SystemExit('v924: missing MM/FS sample '+name+'\n'+out[-1700:])
    seen[name] = int(values[-1],8)
if seen['finish'] < 1 or seen['fail'] != 0 or seen['exit'] < 1 or seen['chld'] < 1 or seen['owner'] < 1 or \
        seen['armed'] == 0 or seen['enter'] < 1 or seen['wait'] < 1 or \
        seen['hold_event'] != 0 or seen['error'] != 0 or \
        seen['held_lease'] != (4 << 18) or \
        seen['wait_lease'] != (4 << 18) or \
        seen['final_lease'] != (4 << 18) or \
        seen['bystander'] < 1 or seen['fatal_count'] != 3 or \
        seen['child_refused'] != 1:
    raise SystemExit('v924: provider ownership/waiter/scheduler violation: '+
                     str(seen)+'\n'+out[-2400:])
if 'HALT' not in out or '<HWCD' not in out or 'H' not in out or \
        'W' not in out or 'C' not in out or \
        'D' not in out or 'P' not in out or \
        re.search(r'S{3,}', out) is None or '!' in out:
    raise SystemExit('v924: guest markers/independent work failed: '+
                     out[-2000:])
print('v934: held-provider CHLD TERM completion PASS:', seen)
PY
