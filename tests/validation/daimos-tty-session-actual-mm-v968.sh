#!/bin/sh
# v897: compile actual proc.c line reset/checked reset against actual PDP-6 MM.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tty-session-actual-mm-v968.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/proc/proc.c" "$work/tty.c" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
start=s.index('void\nproc_tty_line_reset(')
end=s.index('/** Change TTY input mode',start)
frag=s[start:end]
assert 'proc_tty_line_try_reset_v897' in frag
Path(sys.argv[2]).write_text('''#include "proc.h"
#include "mm.h"
#define PROC_TTY_LINE_MM_OWNER_BASE 02000U
extern kword_t proc_tty_line_base_get(unsigned int tty);
extern void proc_tty_line_base_set(unsigned int tty, kword_t base);
'''+frag)
PY
incs=""
for d in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os $incs \
    -S "$work/tty.c" -o "$work/tty.s"
{
    printf '.text\n.globl mm_free\n.globl mm_unpin\n.globl proc_tty_release_session\n'
    printf '.globl proc_tty_line_base_get\n.globl proc_tty_line_base_set\n'
    printf '.equ MM_PIN_FIELD,03770000000\n.equ MM_PIN_ONE,010000000\n'
    sed -n '/^mm_delete:$/,/^; int mm_extent_insert/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_free:$/,/^; int mm_process_transfer_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^[[:space:]]*\.bss$/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^proc_tty_release_session:$/,/^; Remove only trailing FREE/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    sed -n '/^proc_tty_line_base_get:$/,/^; Packed canonical-line SIXBIT helpers/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 190000 --timeout 25 \
    --workdir "$work/run" --name tty-session-actual-mm-v968 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/tty.s" "$work/leaf.s" \
    "$self/daimos-tty-session-actual-mm-v968.s" > "$work/log" 2>&1 || {
        tail -70 "$work/log" >&2
        exit 1
    }
echo 'v968: session MM pin/owner refusal retains ownership, retries release PASS'
