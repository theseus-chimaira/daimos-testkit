#!/bin/sh
# Test-only bitmap prototype, fully isolated from DAIMOS kernel/boot.
set -eu
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
src="$root/tests/validation/d6codec-compressor-v1432"
work="$TMPDIR/d6codec-bitmap-v1432"
mkdir -p "$work/fixtures"
python3 -B "$src/measure-v1432.py" \
    --input "$TMPDIR/d6codec-shell-live-v1426" \
    --output "$work/fixtures"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/bitmap-v1432.dobj" \
    "$src/bitmap-v1432.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/bitmap-v1432.dobj"
for test in "$work/fixtures"/*_both_v1432.s; do
    name=$(basename "$test" .s)
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 \
        --mode deposit --exec-mode go --start 1000 --timeout 60 \
        --workdir "$work/run-$name" --name "$name" \
        --expect __test_exit=0 \
        "$root/tests/validation/daimos-test-crt0-v1.s" \
        "$test" "$src/bitmap-v1432.s"
done
if [ -n "${DAIMOS_REPO:-}" ]; then
    cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic -fPIC -shared \
        "$DAIMOS_REPO/tools/host/d6lz-codec.c" \
        -o "$work/libd6lz36-v1432.so"
    python3 -B "$src/corpus-v1432.py" \
        --dxr-dir "$HOME/git/DAIMOS/build/system/boot/pdp6" \
        --dsh "$HOME/git/DAIMOS/build/system/boot/pdp6/userland-build/userland/dsh.dxr" \
        --d6lz-library "$work/libd6lz36-v1432.so" \
        --output "$work/corpus-v1432.tsv"
fi
if [ "${BITMAP_SPEED_V1432:-0}" = 1 ]; then
    python3 -B "$src/speed-v1432.py" \
        --work "$work" --prefix "$PDP10_PREFIX"
fi
echo 'PASS native bitmap v1432 encode/decode exact-word fixtures'
