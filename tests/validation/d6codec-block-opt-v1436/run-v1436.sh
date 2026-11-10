#!/bin/sh
# Baseline-preserving acceptance of the optimized v1436 block codec.
set -eu
: "${DAIMOS_REPO:?point at the isolated v1436 DAIMOS worktree}"
: "${DAIMOS_BUILD_DXR_DIR:?point at the built PDP-6 DXR directory}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
src="$DAIMOS_REPO/system/kernel/core"
work="$TMPDIR/d6codec-block-opt-v1436"
mkdir -p "$work/fixtures" "$work/errors" "$work/full"
engine="$src/d6codec_block_core_v1436.s"
adapter="$src/d6codec_block_vfs_v1436.s"
crt="$testkit/tests/validation/daimos-test-crt0-v1.s"

python3 -B "$testkit/tests/validation/d6codec-block-v1421/generate-v1421.py" \
    "$DAIMOS_BUILD_DXR_DIR" "$work/fixtures"
python3 -B "$testkit/tests/validation/d6codec-compare-v1422/generate-errors-v1422.py" \
    "$work/errors"

# Both versions must have identical success/error outcomes on
# directly encoded blocks and short/repeated refill windows.
for task in normal_verify zeros_verify literal_verify overlap_verify \
            worst_verify normal_refill literal_refill overlap_refill; do
    sed 's/v1421/v1436/g' "$work/fixtures/${task}_v1421.s" \
        > "$work/fixtures/${task}_v1436.s"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 45 \
        --workdir "$work/pass-$task" --name "$task-v1436" \
        --expect __test_exit=0 "$crt" \
        "$work/fixtures/${task}_v1436.s" "$adapter" "$engine"
done

for case in "$work/errors"/block_*_v1422.s; do
    name=$(basename "$case" _v1422.s)
    sed 's/v1421/v1436/g' "$case" > "$work/fixtures/${name}_v1436.s"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 45 \
        --workdir "$work/fail-$name" --name "$name-v1436" \
        --expect __test_exit=0 "$crt" \
        "$work/fixtures/${name}_v1436.s" "$adapter" "$engine"
done

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 45 \
    --workdir "$work/stack" --name "stack-v1436" \
    --expect __test_exit=0 --examine __v051_first_changed \
    "$testkit/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
    "$work/fixtures/normal_verify_v1436.s" "$adapter" "$engine"

python3 -B "$testkit/tests/validation/d6codec-block-opt-v1436/full-v1436.py" \
    "$DAIMOS_BUILD_DXR_DIR" "$DAIMOS_REPO" "$work/full"
for name in core vfs; do
    case "$name" in
        core) target="$engine" ;;
        vfs) target="$adapter" ;;
    esac
    "$PDP10_PREFIX/bin/das" -F -C -O "$work/$name-v1436.dobj" "$target"
    "$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
        "$work/$name-v1436.dobj"
done
echo "PASS v1436 native: 8 valid, 10 malformed, 1 stack, 5 full DXRs"
