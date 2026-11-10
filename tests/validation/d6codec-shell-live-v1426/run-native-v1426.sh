#!/bin/sh
# Assemble and execute the real v1420/v1424 decoders on ACTUAL guest RAM.
set -eu
: "${DAIMOS_CODEC_REPO:?set to the v1424 isolated decoder checkout}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-shell-live-v1426"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic -shared -fPIC \
    -I"$DAIMOS_CODEC_REPO/system/kernel/core" \
    "$DAIMOS_CODEC_REPO/system/kernel/core/kpack_ram_rle_v1376.c" \
    -o "$work/libkpack-ram-v1376.so"
python3 -B "$testkit/tests/validation/d6codec-shell-live-v1426/measure-v1426.py" \
    --input "$work" --output "$work/measure" --native-fixtures \
    --kpack-library "$work/libkpack-ram-v1376.so"

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -I"$DAIMOS_CODEC_REPO/system/kernel/core" \
    -S "$DAIMOS_CODEC_REPO/system/kernel/core/kpack_ram_rle_v1376.c" \
    -o "$work/kpack-ram-native-v1426.s"

for state in idle_initial after_commands after_function; do
    for codec in grouped block; do
        case $codec in
            grouped)
                adapter="$DAIMOS_CODEC_REPO/system/kernel/core/d6codec_vfs_v1420.s"
                engine="$DAIMOS_CODEC_REPO/system/kernel/core/d6codec_stream_v1420.s"
                ;;
            block)
                adapter="$DAIMOS_CODEC_REPO/system/kernel/core/d6codec_block_vfs_v1424.s"
                engine="$DAIMOS_CODEC_REPO/system/kernel/core/d6codec_block_core_v1424.s"
                ;;
        esac
        name="$state-$codec-live-v1426"
        "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
            --exec-mode go --start 1000 --timeout 65 \
            --workdir "$work/run-$name" --name "$name" \
            --expect __test_exit=0 \
            "$testkit/tests/validation/daimos-test-crt0-v1.s" \
            "$work/measure/${state}_${codec}_live_v1426.s" \
            "$adapter" "$engine"
    done
    name="$state-ram-rle-live-v1426"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 65 \
        --workdir "$work/run-$name" --name "$name" \
        --expect __test_exit=0 \
        "$testkit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/measure/${state}_ram_rle_live_v1426.s" \
        "$work/kpack-ram-native-v1426.s"
done
echo 'PASS 9 real PDP-6 DSH native codec roundtrips v1426'
