#!/bin/sh
# Source-linked real event/finalizer/idle PREVM end-to-end native PDP-6.
# The VM/TTY/MM leaves are controlled to model a refused BACKSTORE owner.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-backstore-event-finalizer-v1500.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1500 work: $work"; fi' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" \
    "$self/daimos-deferred-uarea-v881.s" "$work" <<'PY'
from pathlib import Path
import sys

proc, fixture, work = map(Path, sys.argv[1:])
text = proc.read_text()
begin, end = 'proc_finish_slot:\n', '\nproc_slot_discard:\n'
if text.count(begin) != 1 or end not in text.split(begin, 1)[1]:
    raise AssertionError('v1500: finalizer boundaries changed')
finish = begin + text.split(begin, 1)[1].split(end, 1)[0]
begin, end = 'proc_event_apply:\n', '\nproc_event_nonfatal:\n'
if text.count(begin) != 1 or end not in text.split(begin, 1)[1]:
    raise AssertionError('v1500: event delivery boundaries changed')
event = begin + text.split(begin, 1)[1].split(end, 1)[0]
header = '''        .text
        .globl proc_finish_slot
        .globl proc_finish_service_v881
        .globl proc_event_apply
        .equ PROC_WORDS,3
        .equ PROC_TRANSITION_RH,0200000
        .equ PROC_STATE_LH_MASK,0700000
        .equ PROC_STATE_SLEEP,0300000
        .equ PROC_FILE_TABLE_OFFSET,026
        .equ PROC_FDCTL_OFFSET,024
        .equ PROC_FINALIZE_OFFSET,067
        .equ PROC_FINALIZE_MARK_LH,0400000
        .equ PROC_FINALIZE_PREVM_LH,0100000
        .equ PROC_FATAL_CLOSE_BIT,4
        .equ PROC_WAIT_EVENT_LH,020000
        .equ PROC_WAIT_INTR_LH,060000
        .equ PROC_WAIT_LH_MASK,060000
        .equ CTX_PC,020
'''
(work / 'real-v1500.s').write_text(header + finish + '\n' + event)

s = fixture.read_text()
s = s[s.index('.globl proc_session_teardown\n'):]
old = '''vm_space_destroy:
 aos __vm_calls
 setom 1(1)
 setz 1,
 popj 17,'''
new = '''vm_space_destroy:
 aos __vm_calls
 move 4,__vm_calls
 caie 4,1
 jrst vm_ok_v1500
 seto 1,
 popj 17,
vm_ok_v1500:
 setom 1(1)
 setz 1,
 popj 17,'''
if s.count(old) != 1:
    raise AssertionError('v1500: controlled VM refusal fixture moved')
s = s.replace(old, new, 1)
old = '''__ptable: .block 6
 .word __uarea,,0400407
 .word 04000,,020000'''
new = '''__ptable: .block 6
 .word __uarea,,0400407
 .word 04000,,0'''
if s.count(old) != 1:
    raise AssertionError('v1500: nonresident VM fixture moved')
s = s.replace(old, new, 1)
old = '''__uarea: .block 024
 .word 011'''
new = '''__uarea: .block 024
 .word 0'''
if s.count(old) != 1:
    raise AssertionError('v1500: pending PIPE bit in old fixture')
s = s.replace(old, new, 1)
(work / 'leaves-v1500.s').write_text(s)
PY
cat "$self/daimos-backstore-event-finalizer-v1500.s" \
    "$work/leaves-v1500.s" > "$work/driver-v1500.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 500000 --timeout 30 \
    --workdir "$work/run" --name backstore-event-finalizer-v1500 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/real-v1500.s" \
    "$work/driver-v1500.s" > "$work/log" 2>&1 || {
        tail -65 "$work/log" >&2
        exit 1
    }
echo 'PASS v1500: real TERM -> real PREVM finalizer retains refused DISK owner'
echo 'PASS v1500: idle VM/u-area retries finish once, no repeated HUP/FILE'

# An actual VM refusal must establish PREVM before returning failure.
# Removing that single production call is an executable negative case.
python3 - "$work/real-v1500.s" "$work/unmarked-v1500.s" <<'PY'
from pathlib import Path
import sys

s = Path(sys.argv[1]).read_text()
start = 'proc_finish_prevm_fail_v1081:\n'
end = '\nproc_finish_vm_done:\n'
if s.count(start) != 1 or end not in s.split(start, 1)[1]:
    raise AssertionError('v1500: PREVM ownership stage moved')
part = s.split(start, 1)[1].split(end, 1)[0]
old = '        pushj   17,proc_finish_mark_pending_v892\n'
if part.count(old) != 1:
    raise AssertionError('v1500: PREVM pending marker moved')
new = part.replace(old, '        jrst    proc_finish_fail\n', 1)
Path(sys.argv[2]).write_text(s.replace(start + part, start + new, 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 500000 --timeout 30 \
    --workdir "$work/unmarked" --name unmarked-prevm-v1500 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/unmarked-v1500.s" \
    "$work/driver-v1500.s" > "$work/unmarked.log" 2>&1; then
    echo 'FAIL v1500: missing PREVM ownership falsely accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/unmarked.log" || {
    echo 'FAIL v1500: negative never reached a fixture assertion' >&2
    tail -45 "$work/unmarked.log" >&2
    exit 1
}
echo 'PASS v1500: removing real PREVM marker is rejected'
