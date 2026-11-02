#!/bin/sh
# Validate owner-side priority against the production PDP-6 handler.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fatal-order-v971.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_fatal_close_current_v879\n.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n.equ PROC_TRANSITION_RH,0200000\n.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    printf '.equ PROC_WAIT_EVENT_LH,020000\n.equ CTX_PC,020\n.equ PROC_WAIT_LH_MASK,060000\n'
    sed -n '/^proc_fatal_close_current_v879:$/,/^\/\*\*$/p' "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    printf '.globl proc_deferred_term_check_v926\n'
    sed -n '/^proc_deferred_term_check_v926:$/,/^        popj 17,$/p' "$DAIMOS_REPO/system/kernel/proc/mach_user_pdp6.s"
    printf '.globl proc_event_apply\n'
    sed -n '/^proc_event_apply:$/,/^proc_event_nonfatal:/p' "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
python3 - "$self/daimos-fatal-owner-hup-v970.s" "$work" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text()
out = Path(sys.argv[2])
for name, mask, status in (
    ('all', '016,,1', '0400002'),
    ('int_term', '006,,0', '0400000'),
    ('term_pipe', '004,,1', '0400001'),
    ('pipe', '000,,1', '0400007'),
):
    s = src.replace('movsi 1,010\n iorm 1,__uarea+024',
                    'move 1,[' + mask + ']\n iorm 1,__uarea+024', 1)
    s = s.replace('tlnn 1,010\n jrst term_consumed_v926\n jrst fail_14',
                  'move 2,1\n and 2,[016,,1]\n jumpe 2,term_consumed_v926\n jrst fail_14', 1)
    s = s.replace('caie 1,0400002', 'caie 1,' + status)
    assert s != src
    (out / (name + '.s')).write_text(s)
PY
for name in all int_term term_pipe pipe; do
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
        --workdir "$work/$name" --name "fatal-order-v971-$name" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$work/$name.s" > "$work/$name.log" 2>&1 || {
        tail -50 "$work/$name.log" >&2
        exit 1
    }
    printf 'v971: priority %s PASS\n' "$name"
done
