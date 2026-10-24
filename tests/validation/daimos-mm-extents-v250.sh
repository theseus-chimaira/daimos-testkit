#!/bin/sh
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mm-extents-v250.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
printf '%s\n' '.text' '.globl mm_delete' '.globl mm_extent_insert' '.equ MM_MAX_EXTENTS,040' > "$work/mm-leaves.s"
sed -n '/^mm_delete:/,/^; AC1=base\. Return/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d' >> "$work/mm-leaves.s"
# The production routine now reads a runtime descriptor capacity.
printf '%s\n' '.data' '.globl mm_extent_capacity' 'mm_extent_capacity: .word 040' >> "$work/mm-leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 100000 --timeout 15 --workdir "$work/run" --name daimos-mm-extents-v250 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$self/daimos-mm-extents-v250.s" "$work/mm-leaves.s" >/dev/null
echo 'daimos-mm-extents-v250: PASS (32 entries, full rejection, middle insertion and shifted contents)'
