#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-errors-v1422"
mkdir -p "$work"
python3 -B "$here/tests/validation/d6codec-compare-v1422/generate-errors-v1422.py" "$work"
for codec in grouped block; do
    case $codec in
        grouped) engine="$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1420.s"
            adapter="$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v1420.s" ;;
        block) engine="$DAIMOS_REPO/system/kernel/core/d6codec_block_stream_v1421.s"
            adapter="$DAIMOS_REPO/system/kernel/core/d6codec_block_vfs_v1421.s" ;;
    esac
    for fixture in "$work/$codec"_*_v1422.s; do
        name=$(basename "$fixture" .s)
        "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
            --exec-mode go --start 1000 --timeout 30 \
            --workdir "$work/run-$name" --name "$name" \
            --expect __test_exit=0 \
            "$here/tests/validation/daimos-test-crt0-v1.s" \
            "$fixture" "$adapter" "$engine"
    done
done
echo "PASS v1422 native malformed-stream regression"
