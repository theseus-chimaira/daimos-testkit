#!/bin/sh
# v953 full-system PDP-6: provider returns after long failure and backoff.
# Production sources are NEVER modified; all probes live in a copied kernel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-provider-revival-v953.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
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
        raise SystemExit('v891 isolated hook not unique: ' + rel +
                         ' (' + str(source.count(old)) + ')')
    path.write_text(source.replace(old, new))

# Only the actual hardware APR fault's PI6 trampoline selects a victim.
patch('drivers/clk_io.s',
      'clk_pi_user_fault_exit:\n        movei 1,SYS_WAIT_EVENT_TERM',
      '''clk_pi_user_fault_exit:
        move    4,proc_current_slot
        movem   4,daimos_test_owner_v891
        aos     daimos_test_apr_faults_v891
        movei 1,SYS_WAIT_EVENT_TERM''')

# Mark only the selected owner's FD 0 when calling the actual vfs_sync
# entry. The simulated provider failure occurs *inside* vfs_sync.
patch('fs/file_runtime.s',
      'file_close_vfs:\n        pushj   17,vfs_sync\nfile_close_finish:',
      '''file_close_vfs:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v891
        jrst    daimos_test_vfs_call_v891
        move    4,010
        came    4,file_table
        jrst    daimos_test_vfs_call_v891
        setom   daimos_test_vfs_fd0_v891
daimos_test_vfs_call_v891:
        pushj   17,vfs_sync
        setzm   daimos_test_vfs_fd0_v891
file_close_finish:''')
patch('fs/vfs.s', 'vfs_sync:\n        ldb     7,[POINT 6,1,5]',
      '''vfs_sync:
        skipn   daimos_test_vfs_fd0_v891
        jrst    daimos_test_vfs_normal_v891
        aos     daimos_test_vfs_calls_v891
        move    4,daimos_test_vfs_calls_v891
        caig    4,013
        jrst    daimos_test_vfs_reject_v891
        jrst    daimos_test_vfs_normal_v891 ; provider recovers
daimos_test_vfs_reject_v891:
        aos     daimos_test_vfs_rejects_v891
        movni   1,5                    ; test-only VFS provider refusal
        popj    17,
daimos_test_vfs_normal_v891:
        ldb     7,[POINT 6,1,5]''')

# Record real FILE close passes, owned descriptor preservation, and
# read the production GETTEARDOWN diagnostic while the owner is alive.
patch('fs/file_runtime.s',
      '        move    011,1\n        setz    012,                    ; remember any failed close',
      '''        move    011,1
        move    4,proc_current_slot
        came    4,daimos_test_owner_v891
        jrst    daimos_test_pass_other_v891
        aos     daimos_test_passes_v891
daimos_test_pass_other_v891:
        setz    012,                    ; remember any failed close''')
patch('fs/file_runtime.s',
      '        movem   4,1(011)               ; FILE table+041 = u-area 067',
      '''        movem   4,1(011)               ; FILE table+041 = u-area 067
        move    4,proc_current_slot
        came    4,daimos_test_owner_v891
        jrst    daimos_test_no_probe_v891
        jumpn   012,daimos_test_busy_probe_v891
        skipn   1(011)                 ; witness cleared after success
        aos     daimos_test_witness_clear_v891
        move    4,file_table
        skipn   (4)                    ; selected FD 0 finally gone
        aos     daimos_test_fd_clear_v891
        jrst    daimos_test_no_probe_v891
daimos_test_busy_probe_v891:
        move    4,file_table
        skipn   (4)                    ; failed FD must remain owned
        setom   daimos_test_error_v891
        aos     daimos_test_fd_held_v891
        move    2,proc_current_slot
        iori    2,0400
        pushj   17,proc_control_getteardown_v886
        movem   1,daimos_test_query_v891
        move    4,1
        lsh     4,-017
        caie    4,5
        setom   daimos_test_error_v891
daimos_test_no_probe_v891:''')

# Instrument exactly the actual victim's private-stack timer sleep.
patch('proc/proc_pdp6.s',
      'proc_sleep_ticks:\n        hrrz    1,1',
      '''proc_sleep_ticks:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v891
        jrst    daimos_test_sleep_normal_v891
        aos     daimos_test_sleeps_v891
        move    5,daimos_test_delay_v891
        jumpn   5,daimos_test_delay_known_v891
        movei   5,1
daimos_test_delay_known_v891:
        camn    1,5
        jrst    daimos_test_delay_ok_v891
        setom   daimos_test_error_v891
daimos_test_delay_ok_v891:
        caige   5,01000
        lsh     5,1
        movem   5,daimos_test_delay_v891
daimos_test_sleep_normal_v891:
        hrrz    1,1''')
patch('proc/proc_pdp6.s',
      'proc_exit_current:\n        move    3,1',
      '''proc_exit_current:
        move    4,proc_current_slot
        caie    4,1
        jrst    daimos_test_exit_owner_check_v891
        halt                           ; only after init's final check
        jrst    .-1
daimos_test_exit_owner_check_v891:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v891
        jrst    daimos_test_exit_other_v891
        aos     daimos_test_exits_v891
daimos_test_exit_other_v891:
        move    3,1''')

stats = [
    'owner', 'apr_faults', 'vfs_fd0', 'vfs_calls', 'vfs_rejects',
    'passes', 'sleeps', 'query', 'fd_held', 'fd_clear',
    'witness_clear', 'exits', 'error', 'delay'
]
path = root / 'fs/file_runtime.s'
path.write_text(path.read_text() + '\n        .bss\n' +
                ''.join('        .globl daimos_test_%s_v891\n'
                        'daimos_test_%s_v891: .block 1\n' % (n, n)
                        for n in stats))
PY

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
inc=""
for d in boot core drivers fs ipc mm modules proc storage; do
    inc="$inc -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $inc -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-provider-revival-v953.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
build="$work/build/system/boot/pdp6"
PATH="$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    > "$work/build.log" 2>&1 || {
        tail -55 "$work/build.log" >&2
        echo "v891: isolated kernel/image build failed: $work" >&2
        exit 1
    }
map="$build/kcore.map"
for name in owner apr_faults vfs_calls vfs_rejects passes sleeps query \
    fd_held fd_clear witness_clear exits error delay; do
    symbol="daimos_test_${name}_v891"
    addr=$(awk -v s="$symbol" '$1 == s {print $2}' "$map")
    test -n "$addr" || { echo "v891: no $symbol" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
boot="$build/boot.ini"
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' "$boot"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$boot"
done < "$work/addresses"
printf 'exit\n' >> "$boot"
set +e
(cd "$build"; TERM=dumb timeout -k 2s 120s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -80 "$work/simh.out" >&2
    echo "v891: SIMH failed ($rc): $work" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" <<'PY'
from pathlib import Path
import re
import sys
names = Path(sys.argv[1]).read_text().splitlines()
output = Path(sys.argv[2]).read_text(errors='replace')
counts = {}
for line in names:
    name, address = line.split()
    matches = re.findall(r'(?im)^\s*0*' +
                         re.escape(address.lstrip('0')) +
                         r'\s*:\s*([0-7]+)\b', output)
    if not matches:
        raise SystemExit('v891 missing SIMH sample ' + name +
                         ': ' + output[-1600:])
    counts[name] = int(matches[-1], 8)
print('v891 real APR/FILE fault counters:', counts)
expected = dict(apr_faults=1, vfs_calls=12, vfs_rejects=11,
                passes=12, sleeps=11, fd_held=11,
                fd_clear=1, witness_clear=1, exits=1, error=0)
for name, value in expected.items():
    if counts[name] != value:
        raise SystemExit('v953 mismatch '+name+': '+str(counts)+
                         '\n'+output[-900:])
if counts['delay'] != 0o1000 or counts['owner'] <= 1:
    raise SystemExit('v953: no capped retry before recovery')
if 'HALT' not in output or '<' not in output or 'F' not in output or \
        'P' not in output or '!' in output:
    raise SystemExit('v953 guest markers incorrect: '+output[-900:])
print('v953: provider revival after capped backoff and teardown PASS:', counts)
PY
