#!/bin/sh
# v890 full-system PDP-6: real post-destroy EXEC fatal and VFS refusal.
# Production sources are NEVER modified; all probes live in a copied kernel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-fatal-exec-integration-v890.XXXXXX")
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
        raise SystemExit('v890 isolated hook not unique: ' + rel +
                         ' (' + str(source.count(old)) + ')')
    path.write_text(source.replace(old, new))

# Force only the child's first staged executable load to report NOMEM.
# The production low-memory EXEC path must then destroy its old VM
# itself and return EXEC_REPLACE_FATAL when the second load fails.
patch('proc/exec_lowmem_pdp6.s',
      '        pushj   17,exec_load_process\n'
      '        movem   1,EXEC_R_STAGED+2(17)',
      '''        move    4,proc_current_slot
        caile   4,1
        jrst    daimos_test_stage_nmem_v890
        pushj   17,exec_load_process
        jrst    daimos_test_stage_done_v890
daimos_test_stage_nmem_v890:
        movem   4,daimos_test_owner_v890
        aos     daimos_test_staged_v890
        movni   1,2
daimos_test_stage_done_v890:
        movem   1,EXEC_R_STAGED+2(17)''')
patch('proc/exec_lowmem_pdp6.s',
      'exec_lowmem_old_gone:\n        move    10,EXEC_LM_LAUNCH(17)',
      '''exec_lowmem_old_gone:
        aos     daimos_test_commits_v890
        move    4,1(15)
        camn    4,[-1]                 ; real VM_SPACE_NONE
        jrst    daimos_test_destroyed_v890
        setom   daimos_test_error_v890
daimos_test_destroyed_v890:
        move    10,EXEC_LM_LAUNCH(17)''')
patch('proc/exec_lowmem_pdp6.s',
      '        pushj   17,exec_load_process\n'
      '        move    16,1',
      '''        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_load_normal_v890
        aos     daimos_test_load_fail_v890
        move    4,1(15)                ; VM must remain none
        camn    4,[-1]
        jrst    daimos_test_load_inject_v890
        setom   daimos_test_error_v890
daimos_test_load_inject_v890:
        seto    1,                     ; loader failed after real destroy
        jrst    daimos_test_load_done_v890
daimos_test_load_normal_v890:
        pushj   17,exec_load_process
daimos_test_load_done_v890:
        move    16,1''')

# Confirm that the actual VM teardown set descriptor to none.
patch('proc/vm_pdp6.s',
      '        setom   1(2)                   ; VM_SPACE_NONE',
      '''        setom   1(2)                   ; VM_SPACE_NONE
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_other_vm_v890
        aos     daimos_test_vm_destroy_v890
daimos_test_other_vm_v890:''')

# Mark only the selected owner's FD 0 when calling the actual vfs_sync
# entry. The simulated provider failure occurs *inside* vfs_sync.
patch('fs/file_runtime.s',
      'file_close_vfs:\n        pushj   17,vfs_sync\nfile_close_finish:',
      '''file_close_vfs:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_vfs_call_v890
        move    4,010
        came    4,file_table
        jrst    daimos_test_vfs_call_v890
        setom   daimos_test_vfs_fd0_v890
daimos_test_vfs_call_v890:
        pushj   17,vfs_sync
        setzm   daimos_test_vfs_fd0_v890
file_close_finish:''')
patch('fs/vfs.s', 'vfs_sync:\n        ldb     7,[POINT 6,1,5]',
      '''vfs_sync:
        skipn   daimos_test_vfs_fd0_v890
        jrst    daimos_test_vfs_normal_v890
        aos     daimos_test_vfs_calls_v890
        move    4,daimos_test_vfs_calls_v890
        caig    4,2
        jrst    daimos_test_vfs_reject_v890
        jrst    daimos_test_vfs_normal_v890
daimos_test_vfs_reject_v890:
        aos     daimos_test_vfs_rejects_v890
        movni   1,5                    ; test-only VFS provider refusal
        popj    17,
daimos_test_vfs_normal_v890:
        ldb     7,[POINT 6,1,5]''')

# Record real FILE close passes, owned descriptor preservation, and
# read the production GETTEARDOWN diagnostic while the owner is alive.
patch('fs/file_runtime.s',
      '        move    011,1\n        setz    012,                    ; remember any failed close',
      '''        move    011,1
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_pass_other_v890
        aos     daimos_test_passes_v890
daimos_test_pass_other_v890:
        setz    012,                    ; remember any failed close''')
patch('fs/file_runtime.s',
      '        movem   4,1(011)               ; FILE table+041 = u-area 067',
      '''        movem   4,1(011)               ; FILE table+041 = u-area 067
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_no_probe_v890
        jumpn   012,daimos_test_busy_probe_v890
        skipn   1(011)                 ; witness cleared after success
        aos     daimos_test_witness_clear_v890
        move    4,file_table
        skipn   (4)                    ; selected FD 0 finally gone
        aos     daimos_test_fd_clear_v890
        jrst    daimos_test_no_probe_v890
daimos_test_busy_probe_v890:
        move    4,file_table
        skipn   (4)                    ; failed FD must remain owned
        setom   daimos_test_error_v890
        aos     daimos_test_fd_held_v890
        move    2,proc_current_slot
        iori    2,0400
        pushj   17,proc_control_getteardown_v886
        movem   1,daimos_test_query_v890
        move    4,1
        lsh     4,-017
        caie    4,5
        setom   daimos_test_error_v890
daimos_test_no_probe_v890:''')

# Instrument exactly the actual victim's private-stack timer sleep.
patch('proc/proc_pdp6.s',
      'proc_sleep_ticks:\n        hrrz    1,1',
      '''proc_sleep_ticks:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_sleep_normal_v890
        aos     daimos_test_sleeps_v890
        move    5,proc_current_ptr
        move    5,1(5)
        camn    5,[-1]
        jrst    daimos_test_sleep_vm_none_v890
        setom   daimos_test_error_v890
daimos_test_sleep_vm_none_v890:
        move    4,daimos_test_sleeps_v890
        caie    4,1
        jrst    daimos_test_sleep_2_v890
        camn    1,[1]
        jrst    daimos_test_sleep_normal_v890
        setom   daimos_test_error_v890
daimos_test_sleep_2_v890:
        caie    4,2
        jrst    daimos_test_sleep_normal_v890
        camn    1,[2]
        jrst    daimos_test_sleep_normal_v890
        setom   daimos_test_error_v890
daimos_test_sleep_normal_v890:
        hrrz    1,1''')
patch('proc/proc_pdp6.s',
      'proc_exit_current:\n        move    3,1',
      '''proc_exit_current:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_exit_other_v890
        aos     daimos_test_exits_v890
daimos_test_exit_other_v890:
        move    3,1''')

stats = [
    'owner', 'staged', 'commits', 'vm_destroy', 'load_fail',
    'vfs_fd0', 'vfs_calls', 'vfs_rejects',
    'passes', 'sleeps', 'query', 'fd_held', 'fd_clear',
    'witness_clear', 'exits', 'error'
]
path = root / 'fs/file_runtime.s'
path.write_text(path.read_text() + '\n        .bss\n' +
                ''.join('        .globl daimos_test_%s_v890\n'
                        'daimos_test_%s_v890: .block 1\n' % (n, n)
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
"$cc" -std=c99 -Os $inc -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-fatal-exec-integration-v890.c" -o "$work/user/init.s"
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
        echo "v890: isolated kernel/image build failed: $work" >&2
        exit 1
    }
map="$build/kcore.map"
for name in owner staged commits vm_destroy load_fail vfs_calls vfs_rejects passes sleeps query \
    fd_held fd_clear witness_clear exits error; do
    symbol="daimos_test_${name}_v890"
    addr=$(awk -v s="$symbol" '$1 == s {print $2}' "$map")
    test -n "$addr" || { echo "v890: no $symbol" >&2; exit 1; }
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
(cd "$build"; TERM=dumb timeout -k 2s 65s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -80 "$work/simh.out" >&2
    echo "v890: SIMH failed ($rc): $work" >&2
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
        raise SystemExit('v890 missing SIMH sample ' + name +
                         ': ' + output[-1600:])
    counts[name] = int(matches[-1], 8)
print('v890 real EXEC post-VM/FILE fault counters:', counts)
expected = dict(staged=1, commits=1, vm_destroy=1, load_fail=1,
                vfs_calls=3, vfs_rejects=2,
                passes=3, sleeps=2, fd_held=2, fd_clear=1,
                witness_clear=1, exits=1, error=0)
for name, value in expected.items():
    if counts[name] != value:
        raise SystemExit('v890: ' + name + ': ' + str(counts[name]) +
                         ' expected ' + str(value) + '\n' + output[-900:])
if counts['owner'] <= 1 or counts['query'] >> 15 != 5 or \
        counts['query'] & 3 != 1:
    raise SystemExit('v890: wrong private FILE owner or provider error')
if 'HALT' not in output or '<E' not in output or \
        'H' not in output or '!' in output:
    raise SystemExit('v890: user fault/wait/exit sentinel failed: ' +
                     output[-900:])
print('v890: real EXEC destroys VM, replacement loader fails, '
      'VFS refusal twice, retry, FILE ownership, WAIT PASS')
PY
