#!/bin/sh
# Native PDP-6 restore: a refused unpin must not attempt a second MM free.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-restore-unpin-v1685.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
swap="$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"
{
    printf '%s\n' '.text' '.globl k01_restore_unpin_v1685' \
        'k01_restore_unpin_v1685:'
    awk '
        /^proc_swap_in_read_offset:$/ { inside=1 }
        inside && /^        move    1,\(17\)$/ { start=1 }
        start && (/^        move    1,\(17\)$/ ||
            /^        pushj   17,mm_unpin$/ || /^        jumpn   1,/) { print }
        start && /^        jumpn   1,/ { exit }
    ' "$swap"
    printf '%s\n' '        jrst k01_restore_continue_v1685'
} > "$work/production.s"
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 \
        --timeout 25 --workdir "$work/run-$name" \
        --name "daimos-k01-restore-unpin-v1685-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$source" \
        "$self/daimos-k01-restore-unpin-v1685.s" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -30 "$work/production.log" >&2
    exit 1
}
sed 's/jumpn   1,proc_swap_storage_invariant_v30/jumpn   1,proc_swap_in_free_fail/' \
    "$work/production.s" > "$work/unsafe.s"
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1685: unsafe double-MM-release path unexpectedly passed' >&2
    exit 1
fi
echo 'K01 v1685: refused restore unpin preserves error and avoids MM free, unsafe mutant rejected PASS'
