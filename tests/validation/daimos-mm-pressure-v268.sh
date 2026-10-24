#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mm-pressure-v268.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
printf '%s\n' '.text' '.globl mm_delete' '.globl mm_extent_insert' > "$work/mm.s"
sed -n '/^mm_delete:/,/^; AC1=base\. Return/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d' >> "$work/mm.s"
printf '%s\n' '.data' '.globl mm_extent_capacity' 'mm_extent_capacity: .word 0210' >> "$work/mm.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 400000 --timeout 25 \
  --workdir "$work/run" --name daimos-mm-pressure-v268 \
  --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
  "$self/daimos-mm-pressure-v268.s" "$work/mm.s" >/dev/null
printf '%s\n' 'daimos-mm-pressure-v268: PASS (132→136, rejection, middle reclaim, refill)'
