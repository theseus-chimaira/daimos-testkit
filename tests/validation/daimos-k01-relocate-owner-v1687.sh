#!/bin/sh
# Native PDP-6 stale relocation source guard, with executable mutant.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-relocate-owner-v1687.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
vm="$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s"
{
    printf '%s\n' '.text' '.globl vm_extent_move' '.globl fs_move_words'
    sed -n '/^vm_extent_move:$/,/^\/\*\*/p' "$vm" | sed '$d'
    sed -n '/^fs_copy_words:$/,/^        \.globl  fs_zero_words/p' \
        "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" | sed '$d'
    printf '%s\n' '.data' '.globl kconst_6_6' 'kconst_6_6: .word 6,,6'
} > "$work/production.s"
grep -q '^vm_extent_move_base_ok_v1687:' "$work/production.s"
run()
{
    name=$1
    src=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-relocate-v1687-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-relocate-owner-v1687.s" "$src" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -35 "$work/production.log" >&2
    exit 1
}
sed '/^        hrrz    1,1(14)$/,/^vm_extent_move_base_ok_v1687:$/ {
    s/^        camn    1,11$/        move    1,11/
}' "$work/production.s" > "$work/unsafe.s"
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1687: stale-base relocation mutant passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -35 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1687: native PDP-6 stale MM source refusal, valid move and unsafe mutant PASS'
