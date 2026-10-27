#!/bin/sh
# Native PDP-6 MM relocation descriptor transaction; VM is a controlled stub.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mm-relocation-v531.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
src="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_move_extent' \
        '.equ MM_ALLOC_HIGH,1'
    sed -n '/^mm_delete:/,/^; AC1=base\. Return/p' "$src" | sed '$d'
    sed -n '/^mm_move_extent:/,/^; int mm_compact(words, alignment)/p' "$src" | sed '$d'
} > "$work/leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 160000 --timeout 20 --workdir "$work/run" \
    --name daimos-mm-relocation-v531 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-mm-relocation-v531.s" "$work/leaves.s" >/dev/null
echo 'daimos-mm-relocation-v531: PASS (failure rollback, success publication, descriptor invariants)'
