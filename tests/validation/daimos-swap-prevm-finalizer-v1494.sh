#!/bin/sh
# Real PDP-6 proc_finish_slot + idle finalizer with a refused VM/BSTORE
# release, followed by success and u-area MM failures. No full guest claim.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-prevm-finalizer-v1494.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1494 work: $work"; fi' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" \
    "$self/daimos-deferred-uarea-v881.s" "$self" "$work" <<'PY'
from pathlib import Path
import sys

proc, fixture, tests, work = map(Path, sys.argv[1:])
text = proc.read_text()
start, end = 'proc_finish_slot:\n', '\nproc_slot_discard:\n'
if text.count(start) != 1 or end not in text.split(start, 1)[1]:
    raise AssertionError('production finalizer boundaries changed')
code = start + text.split(start, 1)[1].split(end, 1)[0]
header = '''.text
.globl proc_finish_slot
.globl proc_finish_service_v881
.equ PROC_WORDS,3
.equ PROC_TRANSITION_RH,0200000
.equ PROC_STATE_LH_MASK,0700000
.equ PROC_FILE_TABLE_OFFSET,026
.equ PROC_FDCTL_OFFSET,024
.equ PROC_FINALIZE_OFFSET,067
.equ PROC_FINALIZE_MARK_LH,0400000
.equ PROC_FINALIZE_PREVM_LH,0100000
.equ PROC_FATAL_CLOSE_BIT,4
.equ CTX_PC,020
.equ PROC_WAIT_LH_MASK,060000
'''
(work / 'production-v1494.s').write_text(header + code)
source = fixture.read_text()
source = source[source.index('.globl proc_session_teardown\n'):]
old = '''vm_space_destroy:
 aos __vm_calls
 setom 1(1)
 setz 1,
 popj 17,'''
new = '''vm_space_destroy:
 aos __vm_calls
 move 4,__vm_calls
 caie 4,1
 jrst vm_accept_v1494
 seto 1,
 popj 17,
vm_accept_v1494:
 setom 1(1)
 setz 1,
 popj 17,'''
if source.count(old) != 1:
    raise AssertionError('expected controlled VM release stub moved')
source = source.replace(old, new, 1)
(work / 'driver-v1494.s').write_text(
    (tests / 'daimos-swap-prevm-finalizer-v1494.s').read_text() +
    '\n' + source)
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 25 \
    --workdir "$work/run" --name swap-prevm-finalizer-v1494 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1494.s" \
    "$work/driver-v1494.s" > "$work/log" 2>&1 || {
        tail -70 "$work/log" >&2
        exit 1
    }
echo 'PASS v1494: real finalizer preserves PREVM and retries VM refusal'
echo 'PASS v1494: no repeated HUP/VM after VM commit; MM/uarea retry succeeds'

# Negative control: if the production PREVM failure is incorrectly
# published as success, the first call must violate the owner checks.
python3 - "$work/production-v1494.s" "$work/false-prevm-v1494.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = '''        pushj   17,vm_space_destroy
        jumpe   1,proc_finish_vm_done'''
new = '''        pushj   17,vm_space_destroy
        jrst    proc_finish_vm_done'''
if source.count(old) != 1:
    raise AssertionError('production VM refusal gate moved')
Path(sys.argv[2]).write_text(source.replace(old, new, 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 25 \
    --workdir "$work/false-prevm" --name false-prevm-v1494 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/false-prevm-v1494.s" \
    "$work/driver-v1494.s" > "$work/false-prevm.log" 2>&1; then
    echo 'FAIL v1494: early VM commit mutation passed' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/false-prevm.log" || {
    echo 'FAIL v1494: negative test did not reach an assertion' >&2
    tail -30 "$work/false-prevm.log" >&2
    exit 1
}
echo 'PASS v1494: false VM commit mutation rejected'
