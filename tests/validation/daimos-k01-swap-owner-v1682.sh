#!/bin/sh
# Native PDP-6 exact ownership verification after a successful MM pin.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-swap-owner-v1682.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
swap="$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"

{
    printf '%s\n' '.text' '.globl mm_pin' \
        '.globl mm_process_verify_pinned_v792' \
        '.globl proc_swap_pin_verify_fragment_v1682' \
        '.equ MM_PIN_ONE,010000000' '.equ MM_PIN_FIELD,03770000000' \
        '.equ PROC_TRANSITION_RH,0200000' '.equ MM_TYPE_PROCESS,1'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_process_verify_pinned_v792:$/,/^; Only a process extent pinned exactly once/p' \
        "$mm" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^        \.bss$/p' "$mm" | sed '$d'
    printf '%s\n' 'proc_swap_pin_verify_fragment_v1682:'
    awk '
        /^proc_swap_out_state_ok:$/ { inside = 1 }
        inside && /^        movei   1,PROC_TRANSITION_RH$/ { copy = 1 }
        copy && /^        move    1,16$/ { exit }
        copy { print }
    ' "$swap"
    printf '%s\n' '        jrst proc_swap_pin_done_v1682'
} > "$work/production.s"

run()
{
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 \
        --timeout 25 --workdir "$work/run-$label" \
        --name "daimos-k01-swap-owner-v1682-$label" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-swap-owner-v1682.s" "$source" \
        > "$work/$label.log" 2>&1
}

run production "$work/production.s" || {
    tail -30 "$work/production.log" >&2
    exit 1
}

# Remove only the verifier's guarded error jump, not the earlier mm_pin
# refusal guard. Wrong type/owner/size must now fail this test.
sed '/^        pushj   17,mm_process_verify_pinned_v792$/,/^        jumpn   1,proc_swap_storage_invariant_v30$/ {
    s/jumpn   1,proc_swap_storage_invariant_v30/jumpn   1,proc_swap_pin_done_v1682/
}' "$work/production.s" > "$work/unsafe.s"
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1682: unsafe owner verification unexpectedly passed' >&2
    exit 1
fi
echo 'K01 v1682: exact PDP-6 MM owner/type/length/pin verification and unsafe mutant PASS'
