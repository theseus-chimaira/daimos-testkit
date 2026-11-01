#!/bin/sh
# Native PDP-6 finalizer: defer failed u-area free without repeated VM/HUP.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fatal-mm-stage-v909.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_finish_slot\n.globl proc_finish_service_v881\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_STATE_LH_MASK,0700000\n'
    printf '.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n'
    printf '.equ CTX_PC,020\n'
    printf '.equ PROC_WAIT_LH_MASK,060000\n'
    sed -n '/^proc_finish_slot:$/,/^proc_slot_discard:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
# Isolated pre-v909 negative: preserve original stale FILE stage after MM commit.
if [ "${DAIMOS_V909_NEGATIVE:-0}" = 1 ]; then
    python3 - "$work/leaf.s" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='''        movei   5,PROC_FATAL_CLOSE_BIT
        andcam  5,PROC_FDCTL_OFFSET(3)
'''
assert s.count(old)==1
p.write_text(s.replace(old,'',1))
PY
fi
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 20 \
    --workdir "$work/run" --name fatal-mm-stage-v909 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-fatal-mm-stage-v909.s" > "$work/log" 2>&1 || {
        tail -50 "$work/log" >&2
        exit 1
    }
echo 'v909: native fatal-FILE stage clears after VM commit, MM retained, exact-once finalization PASS'
