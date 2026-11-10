#!/bin/sh
# Compare native C89 v1420/v1424 encoders, not just host Python.
set -eu
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export PDP10_PREFIX TMPDIR
here=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
base="$here/tests/validation/d6codec-compressor-v1429"
work="$TMPDIR/d6codec-compressor-v1429"
mkdir -p "$work"

cc -std=c89 -O2 -Wall -Wextra -Werror -pedantic -fPIC -shared \
    "$base/encode-grouped-v1429.c" \
    "$base/encode-block-v1429.c" \
    "$base/encode-d6lz-v1430.c" \
    "$base/encode-d6lz-fast-v1431.c" \
    -o "$work/libencoder-v1429.so"
if [ -n "${DAIMOS_REPO:-}" ]; then
    cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic -fPIC -shared \
        "$DAIMOS_REPO/tools/host/d6lz-codec.c" \
        -o "$work/libd6lz36-v1430.so"
    d6lz_reference="--d6lz-library $work/libd6lz36-v1430.so"
else
    d6lz_reference=
fi
python3 -B "$base/benchmark-v1429.py" \
    --input "$TMPDIR/d6codec-shell-live-v1426" \
    --library "$work/libencoder-v1429.so" \
    --output "$work/fixtures" $d6lz_reference

for codec in grouped block d6lz d6lz-fast; do
    case "$codec" in
        d6lz) version=v1430 ;;
        d6lz-fast) version=v1431 ;;
        *) version=v1429 ;;
    esac
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -S "$base/encode-$codec-$version.c" \
        -o "$work/encode-$codec-$version.s"
    "$PDP10_PREFIX/bin/das" -F -C \
        -O "$work/encode-$codec-$version.dobj" \
        "$work/encode-$codec-$version.s"
    echo "NATIVE_ENCODER_TEXT $codec"
    "$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
        "$work/encode-$codec-$version.dobj"
done

crt="$here/tests/validation/daimos-test-crt0-v1.s"
for fixture in "$work/fixtures"/*_encode_v1429.s; do
    name=$(basename "$fixture" .s)
    case "$name" in
        *_grouped_encode_v1429) codec=grouped ;;
        *_block_encode_v1429) codec=block ;;
        *_d6lz_encode_v1429) codec=d6lz ;;
        *_d6lz_fast_encode_v1429) codec=d6lz-fast ;;
        *) echo "UNKNOWN TEST CASE $name" >&2; exit 2 ;;
    esac
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 \
        --mode deposit --exec-mode go --start 1000 --timeout 75 \
        --workdir "$work/native-$name" --name "$name" \
        --expect __test_exit=0 "$crt" "$fixture" \
        "$work/encode-$codec-$(case "$codec" in
             d6lz) echo v1430 ;;
             d6lz-fast) echo v1431 ;;
             *) echo v1429 ;;
         esac).s"
done
echo 'PASS all native grouped/block encoder tests v1429'
