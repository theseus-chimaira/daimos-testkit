#!/bin/sh
# Verify both synthetic DSH compressed suffixes using native PDP-6 code.
# The test never changes the DAIMOS kernel, boot media or DSH executable.
set -eu
: "${DAIMOS_REPO:?point to the v1424 decoder source worktree}"
: "${DSH_BUILD_DIR:?point to the compiled DSH assembly directory}"
: "${DSH_DXR:?point to the matching uncompressed DSH DXR}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-shell-mutable-v1425"
mkdir -p "$work"
python3 -B "$testkit/tests/validation/d6codec-shell-mutable-v1425/benchmark-v1425.py" \
    --dxr "$DSH_DXR" --dsh-asm "$DSH_BUILD_DIR" \
    --output "$work" --native-fixtures

for scenario in after_exec idle_prompt running_command function_heavy incompressible_control; do
    for codec in grouped block; do
        case $codec in
            grouped)
                adapter="$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v1420.s"
                engine="$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1420.s"
                ;;
            block)
                adapter="$DAIMOS_REPO/system/kernel/core/d6codec_block_vfs_v1424.s"
                engine="$DAIMOS_REPO/system/kernel/core/d6codec_block_core_v1424.s"
                ;;
        esac
        name="$scenario-$codec-v1425"
        "$PDP10_PREFIX/bin/p10run" \
            --machine pdp6 --mode deposit --exec-mode go \
            --start 1000 --timeout 60 --workdir "$work/native-$name" \
            --name "$name" --expect __test_exit=0 \
            "$testkit/tests/validation/daimos-test-crt0-v1.s" \
            "$work/${scenario}_${codec}_v1425.s" \
            "$adapter" "$engine"
    done
done
echo 'PASS native PDP-6 v1425: ten full-suffix decompressions'
