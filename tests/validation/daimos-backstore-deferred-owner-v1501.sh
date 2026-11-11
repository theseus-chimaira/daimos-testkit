#!/bin/sh
# Real TERM event and deferred owner syscall-return handoff on PDP-6.
# The physical swap restoration and private fatal close are witnesses.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-backstore-deferred-owner-v1501.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1501 work: $work"; fi' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" \
    "$DAIMOS_REPO/system/kernel/proc/mach_user_pdp6.s" "$work" <<'PY'
from pathlib import Path
import sys

proc, mach, work = map(Path, sys.argv[1:])
s = proc.read_text()
begin, end = 'proc_event_apply:\n', '\nproc_event_nonfatal:\n'
if s.count(begin) != 1 or end not in s.split(begin, 1)[1]:
    raise AssertionError('v1501: real event source bounds changed')
event = begin + s.split(begin, 1)[1].split(end, 1)[0]
s = mach.read_text()
begin = 'proc_deferred_term_check_v926:\n'
if s.count(begin) != 1:
    raise AssertionError('v1501: deferred owner entry moved')
tail = s.split(begin, 1)[1]
end = '\n        .globl mach_invalid_uuo_word\n'
if end not in tail:
    raise AssertionError('v1501: deferred owner exit moved')
deferred = begin + tail.split(end, 1)[0]
header = '''        .text
        .globl proc_event_apply
        .globl proc_deferred_term_check_v926
        .equ PROC_TRANSITION_RH,0200000
        .equ PROC_FATAL_CLOSE_BIT,4
        .equ PROC_FDCTL_OFFSET,024
        .equ PROC_FILE_TABLE_OFFSET,026
        .equ PROC_WAIT_LH_MASK,060000
        .equ PROC_WAIT_INTR_LH,060000
        .equ PROC_WAIT_EVENT_LH,020000
        .equ PROC_STATE_LH_MASK,0700000
        .equ PROC_STATE_SLEEP,0300000
        .equ PROC_FINALIZE_OFFSET,067
        .equ PROC_FINALIZE_MARK_LH,0400000
        .equ CTX_PC,020
'''
(work / 'real-v1501.s').write_text(header + event + '\n' + deferred)
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 25 \
    --workdir "$work/run" --name backstore-deferred-owner-v1501 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/real-v1501.s" \
    "$self/daimos-backstore-deferred-owner-v1501.s" \
    > "$work/log" 2>&1 || {
        tail -65 "$work/log" >&2
        exit 1
    }
echo 'PASS v1501: real foreign TERM deferred, repeated and owned safely'
echo 'PASS v1501: restored owner consumes TERM once at syscall return'

# Removing pending-bit consumption would replay a fatal private close
# on the next owner return. This is an executable negative mutation.
python3 - "$work/real-v1501.s" "$work/replayed-v1501.s" <<'PY'
from pathlib import Path
import sys

s = Path(sys.argv[1]).read_text()
old = '''        movsi 3,016
        andcam 3,-2(2)
'''
new = '''        movsi 3,0
        andcam 3,-2(2)
'''
if s.count(old) != 1:
    raise AssertionError('v1501: owner pending-bit consume moved')
Path(sys.argv[2]).write_text(s.replace(old, new, 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 25 \
    --workdir "$work/replayed" --name replayed-owner-v1501 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/replayed-v1501.s" \
    "$self/daimos-backstore-deferred-owner-v1501.s" \
    > "$work/replayed.log" 2>&1; then
    echo 'FAIL v1501: repeated deferred TERM falsely accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/replayed.log" || {
    echo 'FAIL v1501: negative did not reach an assertion' >&2
    tail -40 "$work/replayed.log" >&2
    exit 1
}
echo 'PASS v1501: duplicated deferred fatal consumption rejected'
