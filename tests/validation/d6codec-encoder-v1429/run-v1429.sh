#!/bin/sh
# Compare native PDP-6 test-only LZ encoders and actual v1376 RAM RLE.
set -eu
: "${DAIMOS_REPO:?set to isolated DAIMOS source branch}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-encoder-v1429"
mkdir -p "$work"
cc -std=c89 -O2 -Wall -Wextra -Werror -pedantic -shared -fPIC \
    "$testkit/tests/validation/d6codec-encoder-v1429/encoders-v1429.c" \
    -o "$work/libencoders-v1429.so"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic -shared -fPIC \
    "$DAIMOS_REPO/tools/host/d6lz-codec.c" \
    -o "$work/libd6lz36-v1429.so"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic -shared -fPIC \
    -I"$DAIMOS_REPO/system/kernel/core" \
    "$DAIMOS_REPO/system/kernel/core/kpack_ram_rle_v1376.c" \
    -o "$work/librle-v1429.so"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas -S \
    "$testkit/tests/validation/d6codec-encoder-v1429/encoders-v1429.c" \
    -o "$work/encoders-v1429.s"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -I"$DAIMOS_REPO/system/kernel/core" -S \
    "$DAIMOS_REPO/system/kernel/core/kpack_ram_rle_v1376.c" \
    -o "$work/rle-v1376.s"
"$PDP10_PREFIX/bin/das" -F -C -O \
    "$work/encoders-v1429.dobj" "$work/encoders-v1429.s"
"$PDP10_PREFIX/bin/das" -F -C -O \
    "$work/rle-v1376.dobj" "$work/rle-v1376.s"
python3 -B "$testkit/tests/validation/d6codec-encoder-v1429/generate-v1429.py" \
    --input "$TMPDIR/d6codec-shell-live-v1426" \
    --d6lz-library "$work/libd6lz36-v1429.so" \
    --rle-library "$work/librle-v1429.so" \
    --output "$work/fixtures"
crt="$testkit/tests/validation/daimos-test-crt0-v1.s"
for fixture in "$work/fixtures/"*-verify-v1429.s; do
    name=$(basename "$fixture" .s)
    case "$name" in
        *-rle-*|*-rle_decode-*) encoder="$work/rle-v1376.s" ;;
        *) encoder="$work/encoders-v1429.s" ;;
    esac
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 45 \
        --workdir "$work/test-$name" --name "$name" \
        --expect __test_exit=0 "$crt" "$fixture" "$encoder"
done
if [ "${D6CODEC_ENCODER_STEPS_V1429:-0}" = 1 ]; then
    python3 -B "$testkit/tests/validation/d6codec-encoder-v1429/measure-speed-v1429.py" \
        --testkit "$testkit" --work "$work" --prefix "$PDP10_PREFIX" \
        --tolerance 0.01
fi
echo "PASS four native PDP-6 encoder implementations v1429"
