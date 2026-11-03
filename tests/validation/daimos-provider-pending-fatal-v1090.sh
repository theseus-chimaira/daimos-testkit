#!/bin/sh
# Source-linked PDP-6 fatal-event wake of an undispatched FS lease waiter.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-provider-pending-v1090.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1090 work: $work"; fi' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
work = Path(sys.argv[2])
fs = (root / 'system/kernel/fs/fs_mres.s').read_text()
proc = (root / 'system/kernel/proc/proc_pdp6.s').read_text()
gate = fs.split('fs_provider_reg_call:', 1)[1].split('; KCORE memory-pressure bridge', 1)[0]
event = proc.split('proc_event_fatal_other_defer_term_v926:', 1)[1].split(
    'proc_event_fatal_close_busy_v879:', 1)[0]
assert 'fs_provider_lock_probe_v1090:' in gate
assert 'tlne    1,016' in gate and 'trne    1,01' in gate
assert 'trne    1,04' in gate
assert 'evt_def_fs_check_v1090:' in event
assert 'tlne    5,PROC_WAIT_CHILD_LH' in event
assert 'pushj   17,proc_runq_add' in event
assert 'hrrz    6,5' in event
(work / 'source.s').write_text(
    '.text\n.equ PROC_FDCTL_OFFSET,024\n'
    '.equ PROC_WAIT_EVENT_LH,020000\n'
    '.equ PROC_WAIT_CHILD_LH,040000\n'
    '.equ PROC_STATE_LH_MASK,0700000\n'
    '.equ PROC_STATE_SLEEP,0300000\n'
    '.globl fs_provider_reg_call\n.globl fs_memfs_service_jump\n'
    '.globl fs_dtfs_service_jump\n.globl fs_d6fs_service_jump\n'
    '.globl fs_tsfs_service_jump\nfs_provider_reg_call:' + gate +
    '.globl proc_event_fatal_other_defer_term_v926\n'
    'proc_event_fatal_other_defer_term_v926:' + event)
source = (work / 'source.s').read_text()
bad_abort = source.replace('        tlne    1,016', '        tlne    1,0', 1)
assert bad_abort != source
(work / 'unsafe-abort.s').write_text(bad_abort)
bad_wake = source.replace('        pushj   17,proc_runq_add',
                          '        move    1,010', 1)
assert bad_wake != source
(work / 'unsafe-wake.s').write_text(bad_wake)
bad_class = source.replace('        tlne    5,PROC_WAIT_CHILD_LH',
                           '        tlnn    5,PROC_WAIT_CHILD_LH', 1)
assert bad_class != source
(work / 'unsafe-class.s').write_text(bad_class)
bad_owner = source.replace('        trne    1,04',
                           '        trnn    1,04', 1)
assert bad_owner != source
(work / 'unsafe-owner.s').write_text(bad_owner)
PY
run_native() {
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 30000 --timeout 15 \
        --workdir "$work/run-$1" --name "provider-pending-v1090-$1" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-provider-pending-fatal-v1090.s" "$2" \
        > "$work/log-$1" 2>&1
}
run_native positive "$work/source.s" || {
    tail -80 "$work/log-positive" >&2
    exit 1
}
for kind in abort wake class owner; do
    if run_native "unsafe-$kind" "$work/unsafe-$kind.s"; then
        echo "v1090: unsafe $kind variant unexpectedly passed" >&2
        exit 1
    fi
done
echo 'v1090: targeted TERM wake, fail-closed pre-dispatch, held owner and four negative controls PASS'
