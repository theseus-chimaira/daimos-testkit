#!/bin/sh
# v888: actual mm_free result for pinned versus inconsistent owner metadata.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-uarea-ownership-v956.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl mm_free\n.globl mm_unpin\n.globl proc_control_getteardown_v886\n.globl proc_uarea_release\n'
    printf '.equ MM_PIN_FIELD,03770000000\n.equ MM_PIN_ONE,010000000\n'
    sed -n '/^mm_delete:$/,/^; int mm_extent_insert/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_free:$/,/^; int mm_process_transfer_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^[[:space:]]*\.bss$/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_uarea_probe_v887:$/,/^; Find a fitting free gap/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    printf '.equ PROC_STATE_LH_MASK,0700000\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FATAL_CLOSE_BIT,4\n'
    printf '.equ PROC_TRANSITION_RH,0200000\n.equ PROC_FINALIZE_OFFSET,067\n'
    printf '.equ PROC_FINALIZE_MARK_LH,0400000\n'
    sed -n '/^proc_uarea_release:$/,/^proc_tty_release_session:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    sed -n '/^proc_control_getteardown_v886:$/,/^proc_control_getpgrp:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
if [ -n "${DAIMOS_V1097_MUTANT:-}" ]; then
    python3 - "$work/leaf.s" "$DAIMOS_V1097_MUTANT" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
mode = sys.argv[2]
before = path.read_text()
options = {
    'collapse': (
        'proc_uarea_release_fail:\n        pop     17,10\n'
        '        ; Preserve the real MM_ERR_INVAL (-4) or MM_ERR_BUSY (-5).\n'
        '        ; Both keep descriptor base/flag and exact retry owner untouched.\n'
        '        popj    17,',
        'proc_uarea_release_fail:\n        pop     17,10\n'
        '        ; Preserve the real MM_ERR_INVAL (-4) or MM_ERR_BUSY (-5).\n'
        '        ; Both keep descriptor base/flag and exact retry owner untouched.\n'
        '        jrst    kret_neg1'),
    'early': (
        '        jumpn   1,proc_uarea_release_fail',
        '        jumpe   1,proc_uarea_release_fail'),
    'base': (
        'proc_uarea_release_invalid_v1097:\n        movni   1,4',
        'proc_uarea_release_invalid_v1097:\n        seto    1,'),
}
assert mode in options, 'unknown negative test mode'
old, new = options[mode]
assert before.count(old) == 1, 'source anchor drift: ' + mode
path.write_text(before.replace(old, new, 1))
PY
fi
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 220000 --timeout 25 \
    --workdir "$work/run" --name uarea-ownership-v956 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-uarea-ownership-v956.s" > "$work/log" 2>&1 || {
        tail -54 "$work/log" >&2
        exit 1
    }
echo 'v956: u-area descriptor preserved on MM faults and cleared exactly once PASS'
