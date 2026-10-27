#!/bin/sh
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mm-pin-v526.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
src="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
# Keep the production routines verbatim rather than replacing their logic.
sed -n '/^mm_delete:/,/^; Find a fitting free gap\./p' "$src" | sed '$d' > "$work/pin.s"
sed -n '/^mm_free:/,/^        \.bss$/p' "$src" | sed '$d' >> "$work/pin.s"
printf '%s\n' '.text' '.globl mm_free' '.globl mm_pin' '.globl mm_unpin' \
  '.globl mm_is_pinned' '.globl mm_extent_count' '.globl mm_extents' \
  '.equ MM_PIN_ONE,010000000' '.equ MM_PIN_FIELD,03770000000' >> "$work/pin.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 120000 --timeout 20 --workdir "$work/run" \
  --name daimos-mm-pin-lifetime-v526 --expect __test_exit=0 \
  "$self/daimos-test-crt0-v1.s" "$self/daimos-mm-pin-lifetime-v526.s" \
  "$work/pin.s" >/dev/null
echo 'daimos-mm-pin-lifetime-v526: PASS'
