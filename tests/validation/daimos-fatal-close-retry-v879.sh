#!/bin/sh
# Native PDP-6: irreversible APR/EXEC FILE cleanup stays on the owner stack.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fatal-close-retry-v879.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_fatal_close_current_v879\n.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n.equ PROC_TRANSITION_RH,0200000\n.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    printf '.equ PROC_WAIT_EVENT_LH,020000\n'
    sed -n '/^proc_fatal_close_current_v879:$/,/^\/\*\*$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    printf '.globl proc_event_apply\n'
    sed -n '/^proc_event_apply:$/,/^proc_event_nonfatal:/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name fatal-close-v879 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-fatal-close-retry-v879.s" > "$work/log" 2>&1 || {
        printf 'v879 diagnostic workdir: %s\n' "$work" >&2
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v879: native owner-stack fatal close retries, timer yields and duplicate-fatal exclusion PASS'
