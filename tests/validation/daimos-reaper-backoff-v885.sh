#!/bin/sh
# v885 native PDP-6: one-word capped deferred MM retry backoff.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-reaper-backoff-v885.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_finish_backoff_advance_v885\n.globl proc_finish_defer_uarea_v881\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    sed -n '/^proc_finish_defer_uarea_v881:$/,/^proc_finish_fail:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    sed -n '/^proc_finish_backoff_advance_v885:$/,/^[[:space:]]*\.bss$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 95000 --timeout 20 \
    --workdir "$work/run" --name reaper-backoff-v885 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-reaper-backoff-v885.s" > "$work/log" 2>&1 || {
        tail -50 "$work/log" >&2
        exit 1
    }
echo 'v885: deferred MM backoff doubles and caps, persistent owner stays pending, successful cleanup clears delay PASS'
