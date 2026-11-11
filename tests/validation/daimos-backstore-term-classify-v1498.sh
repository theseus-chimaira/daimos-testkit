#!/bin/sh
# Native PDP-6: actual foreign TERM decision on a nonresident DISK owner.
# Controlled finalizer makes the refusal/commit boundary independently
# observable; no production kernel or backing allocator is modified.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-backstore-term-classify-v1498.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1498 work: $work"; fi' EXIT HUP INT TERM
proc_source="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
{
    cat <<'ASM'
        .text
        .globl proc_event_apply
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
ASM
    sed -n '/^proc_event_apply:$/,/^proc_event_nonfatal:/p' \
        "$proc_source" | sed '$d'
} > "$work/event.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 25 \
    --workdir "$work/run" --name backstore-term-classify-v1498 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/event.s" \
    "$self/daimos-backstore-term-classify-v1498.s" \
    > "$work/test.log" 2>&1 || {
        tail -55 "$work/test.log" >&2
        exit 1
    }
echo 'PASS v1498: WAIT and saved executive return defer foreign TERM'
echo 'PASS v1498: user-return refusal retains disk owner; commit is distinct'

# Executable source mutation: dropping the saved-executive-PC gate
# would allow foreign finalizer to destroy a still-active private stack.
python3 - "$work/event.s" "$work/unguarded.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = ('        tlnn    2,010000               ; no saved executive continuation\n'
       '        jrst    proc_event_fatal_other_defer_term_v926\n')
if source.count(old) != 1:
    raise AssertionError('v1498: saved-PC guard source moved')
# Jump past the deferral branch to foreign close; it must be detected.
new = ('        jrst    .+2\n'
       '        jrst    proc_event_fatal_other_defer_term_v926\n')
Path(sys.argv[2]).write_text(source.replace(old, new, 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 25 \
    --workdir "$work/unguarded" --name unguarded-term-v1498 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/unguarded.s" \
    "$self/daimos-backstore-term-classify-v1498.s" \
    > "$work/unguarded.log" 2>&1; then
    echo 'FAIL v1498: unsafe foreign finalization mutation passed' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/unguarded.log" || {
    echo 'FAIL v1498: mutation did not reach fixture assertion' >&2
    tail -40 "$work/unguarded.log" >&2
    exit 1
}
echo 'PASS v1498: unsafe saved-PC bypass rejected'
