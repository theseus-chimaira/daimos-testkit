#!/bin/sh
# Source-linked production MM release branch and actual PDP-6 mm_free.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-swap-free-v1683.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
swap="$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_free' \
        '.globl proc_swap_free_fragment_v1683' '.equ MM_TYPE_PROCESS,1'
    sed -n '/^mm_delete:$/,/^; int mm_extent_insert/p' "$mm" | sed '$d'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_free:$/,/^; int mm_process_transfer_pinned/p' "$mm" | sed '$d'
    printf '%s\n' 'proc_swap_free_fragment_v1683:' \
        '        move    1,013' '        movei   2,MM_TYPE_PROCESS' \
        '        move    3,010'
    # Extract the actual release call and refusal branch, not a copy.
    sed -n '/^        pushj   17,mm_free$/,+6p' "$swap" | \
        sed -n '1,/^        jumpn   1,/p'
    printf '%s\n' '        jrst proc_swap_free_ok_v1683'
} > "$work/production.s"
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 \
        --timeout 25 --workdir "$work/run-$name" \
        --name "daimos-k01-swap-free-v1683-$name" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-swap-free-v1683.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -25 "$work/production.log" >&2
    exit 1
}
sed 's/jumpn   1,proc_swap_storage_invariant_v30/jumpn   1,proc_swap_out_record_fail/' \
    "$work/production.s" > "$work/unsafe.s"
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1683: unsafe free-refusal branch unexpectedly passed' >&2
    exit 1
fi
echo 'K01 v1683: physical MM owner/pin free refusal retains TRANSITION, normal free and unsafe mutant PASS'
