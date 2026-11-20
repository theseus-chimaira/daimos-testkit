#!/bin/sh
# Source-linked native PDP-6 test: verify newly pinned swap-in MM owner.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-restore-owner-v1686.XXXXXX")
if [ "${K01_KEEP_WORK:-0}" = 1 ]; then
    printf 'K01 debug files: %s\n' "$work"
else
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
swap="$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"

{
    printf '%s\n' '.text' '.globl mm_pin' \
        '.globl mm_process_verify_pinned_v792' \
        '.globl proc_swap_in_verify_fragment_v1686' \
        '.equ MM_PIN_ONE,010000000' '.equ MM_PIN_FIELD,03770000000' \
        '.equ PROC_TRANSITION_RH,0200000' '.equ MM_TYPE_PROCESS,1'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_process_verify_pinned_v792:$/,/^; Only a process extent pinned exactly once/p' \
        "$mm" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^        \.bss$/p' "$mm" | sed '$d'
    printf '%s\n' 'proc_swap_in_verify_fragment_v1686:'
    awk '
        /^proc_swap_in:$/ { inside = 1 }
        inside && /^        pushj   17,mm_pin$/ {
            print "        move    1,(17)"
            print
            copy = 1
            next
        }
        copy && /^        move    1,14$/ { exit }
        copy { print }
    ' "$swap"
    printf '%s\n' '        jrst k01_restore_verified_v1686'
} > "$work/production.s"
grep -q 'pushj   17,mm_process_verify_pinned_v792' "$work/production.s"
grep -q 'jumpn   1,proc_swap_storage_invariant_v30' "$work/production.s"

run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 \
        --timeout 25 --workdir "$work/run-$name" \
        --name "daimos-k01-restore-owner-v1686-$name" --expect __test_exit=0 \
        --examine k01_invariant_calls --examine k01_verified_calls \
        --examine k01_pin_fail_calls --examine k01_proc \
        --examine k01_disk_record --examine mm_extent_count \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-restore-owner-v1686.s" "$source" \
        > "$work/$name.log" 2>&1
}

run production "$work/production.s" || {
    tail -30 "$work/production.log" >&2
    exit 1
}

# Replace only the post-verification refusal, not the physical pin guard.
sed '/^        pushj   17,mm_process_verify_pinned_v792$/,/^        jumpn   1,proc_swap_storage_invariant_v30$/ {
    s/jumpn   1,proc_swap_storage_invariant_v30/jumpn   1,k01_restore_verified_v1686/
}' "$work/production.s" > "$work/unsafe.s"
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1686: unsafe swap-in owner bypass unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    echo 'K01 v1686: unsafe mutant did not reach the native assertion' >&2
    tail -30 "$work/unsafe.log" >&2
    exit 1
}

echo 'K01 v1686: native PDP-6 swap-in exact MM type/owner/size/pins and unsafe mutant PASS'
