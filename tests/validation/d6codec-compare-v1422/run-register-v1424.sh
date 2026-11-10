#!/bin/sh
# Native standalone acceptance for the register-resident block codec.
set -eu
: "${DAIMOS_REPO:?}"
: "${DAIMOS_BUILD_DXR_DIR:?}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-register-v1424"
mkdir -p "$work"
python3 -B "$testkit/tests/validation/d6codec-block-v1421/generate-v1421.py" \
    "$DAIMOS_BUILD_DXR_DIR" "$work"
python3 -B "$testkit/tests/validation/d6codec-compare-v1422/generate-errors-v1422.py" \
    "$work/errors"
engine="$DAIMOS_REPO/system/kernel/core/d6codec_block_core_v1424.s"
adapter="$DAIMOS_REPO/system/kernel/core/d6codec_block_vfs_v1424.s"
crt="$testkit/tests/validation/daimos-test-crt0-v1.s"

for task in normal_verify zeros_verify literal_verify overlap_verify \
            worst_verify normal_refill literal_refill overlap_refill; do
    sed 's/v1421/v1424/g' "$work/${task}_v1421.s" \
        > "$work/${task}_v1424.s"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 40 \
        --workdir "$work/verify-$task" --name "register-$task-v1424" \
        --expect __test_exit=0 "$crt" "$work/${task}_v1424.s" \
        "$adapter" "$engine"
done

for fixture in "$work/errors"/block_*_v1422.s; do
    name=$(basename "$fixture" .s)
    sed 's/v1421/v1424/g' "$fixture" > "$work/${name}_v1424.s"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/negative-$name" --name "register-$name-v1424" \
        --expect __test_exit=0 "$crt" "$work/${name}_v1424.s" \
        "$adapter" "$engine"
done

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 40 \
    --workdir "$work/stack" --name "register-stack-v1424" \
    --expect __test_exit=0 --examine __v051_first_changed \
    "$testkit/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
    "$work/normal_verify_v1424.s" "$adapter" "$engine"
"$PDP10_PREFIX/bin/das" -F -C \
    -O "$work/engine-v1424.dobj" "$engine"
"$PDP10_PREFIX/bin/das" -F -C \
    -O "$work/adapter-v1424.dobj" "$adapter"
echo REGISTER_CORE_SIZE
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h "$work/engine-v1424.dobj"
echo REGISTER_ADAPTER_SIZE
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h "$work/adapter-v1424.dobj"
echo "PASS register-resident block codec native acceptance v1424"
