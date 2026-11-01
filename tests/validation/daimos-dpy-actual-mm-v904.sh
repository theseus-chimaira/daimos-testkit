#!/bin/sh
# Native PDP-6 DPY final CLOSE: real MM pin, owner, and extent lifetime.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dpy-actual-mm-v904.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" \
    "$work/stop.s" "${DAIMOS_V904_NEGATIVE:-0}" <<'PY'
from pathlib import Path
import re
import sys
source = Path(sys.argv[1]).read_text()
start = source.index('dpy_list_stop:\n')
end = source.index('/**\n * @brief Update the retained Type-342', start)
fragment = source[start:end]
if sys.argv[3] == '1':
    # Isolated pre-v904 instruction ordering. It must fail the contract.
    first = '        cono 0130,000100               ; INIT, PIA disabled\n'
    second = '        setzm dpy_list_base\n'
    assert first in fragment and second in fragment
    fragment = fragment.replace(first, '', 1).replace(second,
        second + first, 1)
lines = [re.sub(r';.*$', '', line).strip().lower()
         for line in fragment.splitlines()]
quiesce = lines.index('cono 0130,000100')
unpublish = lines.index('setzm dpy_list_base')
if quiesce >= unpublish:
    raise SystemExit('v904 FAIL: published DPY list removed before CONO quiesce')
Path(sys.argv[2]).write_text('.text\n.globl dpy_list_stop\n' + fragment)
PY
{
    printf '.text\n.globl file_close_entry_v865\n.globl dpy_close_words_call\n'
    sed -n '/^file_close_entry_v865:$/,/^; int file_dup(int fd)/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    cat "$work/stop.s"
    printf '.globl mm_unpin\n.equ MM_PIN_FIELD,03770000000\n.equ MM_PIN_ONE,010000000\n'
    sed -n '/^mm_delete:$/,/^; int mm_extent_insert/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_free:$/,/^; int mm_process_transfer_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^[[:space:]]*\.bss$/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 25 \
    --workdir "$work/run" --name dpy-actual-mm-v904 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-dpy-actual-mm-v904.s" > "$work/log" 2>&1 || {
        tail -60 "$work/log" >&2
        exit 1
    }
echo 'v904: native PDP-6 DPY stop ordering and actual MM pin/owner/retry PASS'
