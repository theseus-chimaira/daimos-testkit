#!/bin/sh
# Native PDP-6: marked idle finalizer never re-enters sleeping HUP.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-slot0-finish-hup-v1086.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_finish_slot\n.globl proc_finish_service_v881\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_STATE_LH_MASK,0700000\n'
    printf '.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    printf '.equ PROC_FINALIZE_PREVM_LH,0100000\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n.equ CTX_PC,020\n'
    printf '.equ PROC_WAIT_LH_MASK,060000\n'
    sed -n '/^proc_finish_slot:$/,/^proc_slot_discard:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
python3 - "$self/daimos-deferred-uarea-v881.s" "$work/stubs.s" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
source = source[source.index('.globl proc_session_teardown\n'):]
# HUP on the PI6-masked path is forbidden; if it happens, record the
# attempted call and return failure instead of silently continuing.
source = source.replace('''proc_session_teardown:
 aos __hup_calls
 setz 1,
 popj 17,''', '''proc_session_teardown:
 aos __hup_calls
 seto 1,
 popj 17,''', 1)
Path(sys.argv[2]).write_text(source)
PY
cat "$self/daimos-slot0-finish-hup-v1086.s" "$work/stubs.s" > "$work/test.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 320000 --timeout 25 \
    --workdir "$work/run" --name slot0-finish-hup-v1086 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$work/test.s" \
    > "$work/log" 2>&1 || {
        tail -70 "$work/log" >&2
        exit 1
    }
echo 'v1086: marked PI6-masked PREVM bypasses HUP and retries MM once PASS'
