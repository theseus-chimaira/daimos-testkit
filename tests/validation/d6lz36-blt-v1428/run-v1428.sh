#!/bin/sh
# Test production D6LZ36 BLT core; no kernel or media modifications.
set -eu
: "${DAIMOS_REPO:?use isolated v1428 DAIMOS worktree}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export PDP10_PREFIX TMPDIR
here=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6lz36-blt-v1428"
mkdir -p "$work"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic -fPIC -shared \
    "$DAIMOS_REPO/tools/host/d6lz-codec.c" \
    -o "$work/libd6lz36-v1428.so"
python3 -B "$here/tests/validation/d6lz36-blt-v1428/generate-v1428.py" \
    --library "$work/libd6lz36-v1428.so" \
    --snapshot "$TMPDIR/d6codec-shell-live-v1426" \
    --output "$work/generated"
crt="$here/tests/validation/daimos-test-crt0-v1.s"
runtime="$DAIMOS_REPO/system/kernel/core/d6lz_pdp6.s"
core="$DAIMOS_REPO/system/stand/pdp6/common/decompressor.inc"
for file in "$work/generated"/*_v1428.s; do
    name=$(basename "$file" .s)
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 50 \
        --workdir "$work/test-$name" --name "$name" \
        --expect __test_exit=0 "$crt" "$file" "$runtime" "$core"
done
"$PDP10_PREFIX/bin/das" -F -C -O "$work/core-v1428.dobj" "$core"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h "$work/core-v1428.dobj"
if [ "${D6LZ36_BLT_MEASURE_V1428:-0}" = 1 ]; then
    python3 -B "$here/tests/validation/d6lz36-blt-v1428/measure-speed-v1428.py" \
        --daimos "$DAIMOS_REPO" \
        --input "$TMPDIR/d6codec-shell-live-v1426" \
        --library "$work/libd6lz36-v1428.so" \
        --prefix "$PDP10_PREFIX" --output "$work/steps"
fi
echo "PASS original-bitstream D6LZ36 BLT native acceptance v1428"
