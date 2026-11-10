#!/bin/sh
# Exact PDP-6 bitmap codec validation against v1432 reference streams.
set -eu
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
src="$root/tests/validation/d6codec-compressor-v1445"
ref="$root/tests/validation/d6codec-compressor-v1432"
work="$TMPDIR/d6codec-bitmap-v1445"
mkdir -p "$work/reference" "$work/fixtures"
python3 -B "$ref/measure-v1432.py" \
    --input "$TMPDIR/d6codec-shell-live-v1426" \
    --output "$work/reference"
for fixture in "$work/reference"/*_both_v1432.s; do
    name=$(basename "$fixture" _v1432.s)
    sed 's/v1432/v1445/g' "$fixture" > "$work/fixtures/${name}_v1445.s"
done
"$PDP10_PREFIX/bin/das" -F -C -O "$work/bitmap-v1445.dobj" \
    "$src/bitmap-v1445.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/bitmap-v1445.dobj"
for fixture in "$work/fixtures"/*_both_v1445.s; do
    name=$(basename "$fixture" .s)
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 \
        --mode deposit --exec-mode go --start 1000 --timeout 65 \
        --workdir "$work/run-$name" --name "$name" \
        --expect __test_exit=0 \
        "$root/tests/validation/daimos-test-crt0-v1.s" \
        "$fixture" "$src/bitmap-v1445.s"
done
echo 'PASS 8 native bitmap v1445 encode/decode exact-word fixtures'
