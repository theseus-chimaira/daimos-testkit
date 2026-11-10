#!/bin/sh
# Reproducible native assembler and real PDP-6 full-profile tape boot test.
# All products and writable media stay under TMPDIR, not the DAIMOS tree.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to the v1460 source worktree}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
case_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/d6codec-v1460-native-acceptance"
mkdir -p "$work/host" "$work/source-regression"

python3 -B "$case_dir/register-liveness-v1460.py" \
    --daimos "$DAIMOS_REPO" --prefix "$PDP10_PREFIX" \
    --work "$work/source-regression"

make -C "$DAIMOS_REPO/tools/host" \
    "$work/host/d6block-v1452" BUILD="$work/host"

for device in dtc mtc; do
    build="$work/build-$device"
    mkdir -p "$build"
    echo "BUILD_v1460_BOOT $device"
    make -C "$DAIMOS_REPO/system/boot/pdp6" -j4 image \
        BOOT="$device" ROOT=disk BUILD="$build" \
        BUILD_ROOT="$work/source-$device" \
        PDP10_PREFIX="$PDP10_PREFIX" \
        D6BLOCK_HOST="$work/host/d6block-v1452" \
        > "$work/build-$device.log" 2>&1 || {
            tail -50 "$work/build-$device.log" >&2
            exit 1
        }
    case "$device" in
        dtc) dcs=22510; ge=22511 ;;
        mtc) dcs=22520; ge=22521 ;;
    esac
    python3 -B "$case_dir/../d6codec-v1459-integration/boot-v1459.py" \
        --boot "$build" --prefix "$PDP10_PREFIX" \
        --output "$work/boot-$device" \
        --dcs-port "$dcs" --ge-port "$ge" --timeout 180 \
        > "$work/boot-$device.log" 2>&1 || {
            tail -50 "$work/boot-$device.log" >&2
            exit 1
        }
    cat "$work/boot-$device.log"
    echo "PASS_v1460_FULL_BOOT $device"
done
echo 'PASS v1460: AC16 entry preserved, zero growth, DTC/MTC full boots'
