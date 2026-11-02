#!/bin/sh
# Test production swap-in rollback branches, including MM error outcomes.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-in-rollback-v958.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_swap_in_read_fail\n.globl proc_swap_in_pin_fail\n'
    printf '.equ MM_TYPE_PROCESS,1\n.equ PROC_TRANSITION_RH,0200000\n'
    sed -n '/^proc_swap_in_read_fail:$/,/^proc_swap_in_alloc_status:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 120000 --timeout 20 \
    --workdir "$work/run" --name swap-in-rollback-v958 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-swap-in-rollback-v958.s" > "$work/log" 2>&1 || {
        tail -65 "$work/log" >&2
        exit 1
    }
echo 'v958: failed unpin/free rollback retains TRANSITION and traps invariant PASS'
