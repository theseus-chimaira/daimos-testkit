#!/bin/sh
# Native PDP-6 swap-out entry must exclude an owned fatal-close stack.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fatal-swap-guard-v879.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_swap_out\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_STATE_RUN,2\n.equ PROC_STATE_SLEEP,3\n.equ PROC_STATE_STOP,6\n'
    printf '.equ PROC_TRANSITION_RH,0200000\n.equ PROC_UAREA_RH,0400000\n'
    printf '.equ PROC_FDCTL_OFFSET,024\n.equ PROC_USER_MAP_BIT,2\n.equ PROC_FATAL_CLOSE_BIT,4\n'
    sed -n '/^proc_swap_out:$/,/^        move    12,proc_swap_records$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
    printf 'proc_swap_out_guard_pass_v879:\n'
    printf ' aos __guard_pass\n setz 1,\n jrst proc_swap_out_guard_restore_v879\n'
    printf 'proc_swap_out_fail:\n seto 1,\n'
    printf 'proc_swap_out_guard_restore_v879:\n'
    printf ' movei 0,10\n hrli 0,-6(17)\n blt 0,16\n'
    printf ' sub 17,kconst_7_7\n popj 17,\n'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name fatal-swap-guard-v879 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-fatal-swap-guard-v879.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v879: native swap-out guard rejects fatal continuation, mapping hold and transition PASS'
