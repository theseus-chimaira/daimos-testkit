#!/bin/sh
# Physical PDP-6 MM unpin, original swap verify-failure exit, and an unsafe mutant.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-verify-unpin-v1680.XXXXXX")
if [ "${K01_KEEP_WORK:-0}" = 1 ]; then
    printf 'K01 debug files: %s\n' "$work"
else
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
swap="$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"

{
    printf '%s\n' '.text' '.globl mm_unpin' \
        '.globl proc_swap_out_verify_fail' \
        '.equ MM_PIN_ONE,010000000' '.equ MM_PIN_FIELD,03770000000' \
        '.equ PROC_TRANSITION_RH,0200000'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^        \.bss$/p' "$mm" | sed '$d'
    sed -n '/^proc_swap_out_clear:$/,/^proc_swap_out_restore:$/p' "$swap" | sed '$d'
    # The extracted production block normally falls into its full
    # transaction epilogue. Preserve that edge using the test-only ABI.
    printf '%s\n' '        jrst proc_swap_out_restore'
    sed -n '/^proc_swap_out_verify_fail:$/,/^\.endif$/p' "$swap" | sed '$d'
} > "$work/production.s"

run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 \
        --timeout 25 --workdir "$work/run-$name" \
        --name "daimos-k01-verify-unpin-v1680-$name" \
        --expect __test_exit=0 --report "$work/$name.report.txt" \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-verify-unpin-v1680.s" "$source" \
        > "$work/$name.log" 2>&1
}

run production "$work/production.s" || {
    tail -30 "$work/production.log" >&2
    exit 1
}

# Recreate the pre-v1679 unsafe return without editing the production tree.
# The normal pinned case must still pass; at least one refusal must fail.
sed '/^proc_swap_out_verify_fail:$/,/^\.endif$/ {
    /jumpn   1,proc_swap_storage_invariant_v30/d
}' "$work/production.s" > "$work/unsafe.s"
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1680: UNSAFE verify rollback unexpectedly passed' >&2
    exit 1
fi

echo 'K01 v1680: real PDP-6 pin release, missing pin, absent descriptor, TRANSITION guard and unsafe mutant PASS'
