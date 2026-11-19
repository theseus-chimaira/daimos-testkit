#!/bin/sh
# Source-linked PDP-6 MM pin plus swap transition and unsafe negative control.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-swap-pin-v1681.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
swap="$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"

{
    printf '%s\n' '.text' '.globl mm_pin' \
        '.globl proc_swap_pin_fragment_v1681' \
        '.equ MM_PIN_ONE,010000000' '.equ MM_PIN_FIELD,03770000000' \
        '.equ PROC_TRANSITION_RH,0200000'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^        \.bss$/p' "$mm" | sed '$d'
    printf '%s\n' 'proc_swap_pin_fragment_v1681:'
    awk '
        /^proc_swap_out_state_ok:$/ { inside = 1 }
        inside && /^        movei   1,PROC_TRANSITION_RH$/ { copy = 1 }
        copy { print }
        copy && /^        jumpn   1,proc_swap_storage_invariant_v30$/ { exit }
    ' "$swap"
    printf '%s\n' '        jrst proc_swap_pin_ok_v1681'
    sed -n '/^proc_swap_out_clear:$/,/^proc_swap_out_restore:$/p' "$swap" | sed '$d'
    printf '%s\n' '        jrst proc_swap_out_restore'
} > "$work/production.s"

run()
{
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 \
        --timeout 25 --workdir "$work/run-$label" \
        --name "daimos-k01-swap-pin-v1681-$label" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-swap-pin-v1681.s" "$source" \
        > "$work/$label.log" 2>&1
}

run production "$work/production.s" || {
    tail -30 "$work/production.log" >&2
    exit 1
}

# The historical unsafe branch cleared TRANSITION even though no pin
# was acquired. Do not allow that old behaviour to satisfy the test.
sed 's/jumpn   1,proc_swap_storage_invariant_v30/jumpn   1,proc_swap_out_clear/' \
    "$work/production.s" > "$work/unsafe.s"
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1681: unsafe MM-pin refusal unexpectedly passed' >&2
    exit 1
fi
echo 'K01 v1681: real PDP-6 missing/saturated MM pin fails closed, valid owner pins, unsafe mutant rejected PASS'
