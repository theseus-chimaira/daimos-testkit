#!/bin/sh
# Native comparison of unchanged grouped v1367, fast v1420 and block v1421.
# Everything runs in an isolated TMPDIR; no production image is relinked.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to the isolated DAIMOS checkout}"
: "${DAIMOS_BUILD_DXR_DIR:?set DAIMOS_BUILD_DXR_DIR to current DXR build}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-compare-v1422"
mkdir -p "$work"
python3 -B "$here/tests/validation/d6codec-fastpath-v1420/generate-v1420.py" \
    "$DAIMOS_BUILD_DXR_DIR" "$work/grouped"
python3 -B "$here/tests/validation/d6codec-block-v1421/generate-v1421.py" \
    "$DAIMOS_BUILD_DXR_DIR" "$work/block"

# Keep an unmodified, independently compiled v1367 as the control.
# Renaming labels is solely to reuse the v1420 generated fixture ABI.
git -C "$DAIMOS_REPO" show \
    d6codec-cutover-v1352-20261108:system/kernel/core/d6codec_stream_v1367.s \
    | sed -e 's/v1367/v1420/g' -e 's/V1367/V1420/g' \
    > "$work/d6codec_stream_baseline_v1422.s"
git -C "$DAIMOS_REPO" show \
    d6codec-cutover-v1352-20261108:system/kernel/core/d6codec_vfs_v1367.s \
    | sed -e 's/v1367/v1420/g' -e 's/V1367/V1420/g' \
    > "$work/d6codec_vfs_baseline_v1422.s"

for codec in grouped block; do
    case $codec in
        grouped) engine="$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1420.s"
            adapter="$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v1420.s"
            version=v1420 ;;
        block) engine="$DAIMOS_REPO/system/kernel/core/d6codec_block_stream_v1421.s"
            adapter="$DAIMOS_REPO/system/kernel/core/d6codec_block_vfs_v1421.s"
            version=v1421 ;;
    esac
    for task in normal_verify zeros_verify literal_verify overlap_verify \
                worst_verify normal_refill literal_refill overlap_refill; do
        case $task in
            literal_refill|normal_refill|overlap_refill|*_verify)
                : ;;
        esac
        "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
            --exec-mode go --start 1000 --timeout 40 \
            --workdir "$work/validate-$codec-$task" \
            --name "d6codec-$codec-$task-v1422" --expect __test_exit=0 \
            "$here/tests/validation/daimos-test-crt0-v1.s" \
            "$work/$codec/${task}_$version.s" "$adapter" "$engine"
    done
done
for task in normal_verify zeros_verify literal_verify overlap_verify \
            worst_verify normal_refill literal_refill overlap_refill; do
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 40 \
        --workdir "$work/validate-baseline-$task" \
        --name "d6codec-baseline-$task-v1422" --expect __test_exit=0 \
        "$here/tests/validation/daimos-test-crt0-v1.s" \
        "$work/grouped/${task}_v1420.s" \
        "$work/d6codec_vfs_baseline_v1422.s" \
        "$work/d6codec_stream_baseline_v1422.s"
done

# Native stack canary: use a verified input and save the measured
# first changed stack cell. Real nested VFS/provider stacks are separate.
for codec in baseline grouped block; do
    case $codec in
        baseline) engine="$work/d6codec_stream_baseline_v1422.s"
            adapter="$work/d6codec_vfs_baseline_v1422.s"
            fixture="$work/grouped/normal_verify_v1420.s" ;;
        grouped) engine="$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1420.s"
            adapter="$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v1420.s"
            fixture="$work/grouped/normal_verify_v1420.s" ;;
        block) engine="$DAIMOS_REPO/system/kernel/core/d6codec_block_stream_v1421.s"
            adapter="$DAIMOS_REPO/system/kernel/core/d6codec_block_vfs_v1421.s"
            fixture="$work/block/normal_verify_v1421.s" ;;
    esac
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 40 \
        --workdir "$work/stack-$codec" \
        --name "d6codec-$codec-stack-v1422" --expect __test_exit=0 \
        --examine __v051_first_changed \
        "$here/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
        "$fixture" "$adapter" "$engine" \
        > "$work/stack-$codec-v1422.log"
    grep -A2 '__P10RUN_EXPECT__' "$work/stack-$codec-v1422.log" | tail -3
done

for codec in baseline grouped block; do
    case $codec in
        baseline) engine="$work/d6codec_stream_baseline_v1422.s"
            adapter="$work/d6codec_vfs_baseline_v1422.s" ;;
        grouped) engine="$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1420.s"
            adapter="$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v1420.s" ;;
        block) engine="$DAIMOS_REPO/system/kernel/core/d6codec_block_stream_v1421.s"
            adapter="$DAIMOS_REPO/system/kernel/core/d6codec_block_vfs_v1421.s" ;;
    esac
    "$PDP10_PREFIX/bin/das" -F -C \
        -O "$work/engine-$codec-v1422.dobj" "$engine"
    "$PDP10_PREFIX/bin/das" -F -C \
        -O "$work/adapter-$codec-v1422.dobj" "$adapter"
    printf '%s engine ' "$codec"
    "$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
        "$work/engine-$codec-v1422.dobj" | head -1
    printf '%s adapter ' "$codec"
    "$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
        "$work/adapter-$codec-v1422.dobj" | head -1
done

python3 -B "$here/tests/validation/d6codec-compare-v1422/measure-v1422.py" \
    "$work" "$here" "$DAIMOS_REPO"
echo "PASS native grouped/block comparison v1422"
