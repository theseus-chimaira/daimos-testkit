#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/d6codec-runtime-exec-v1369"
work="$TMPDIR/d6codec-runtime-v1369"
core="$DAIMOS_REPO/system/kernel"
boot="$DAIMOS_REPO/build/system/boot/pdp6"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
runner="$PDP10_PREFIX/bin/p10run"
mkdir -p "$work"

# Compile a REAL PDP-6 program with C89 and link a normal DXR. This
# program is executed from the decoded VM image by the native fixture.
"$cc" -std=c89 -Os -march=pdp6 -mcpu=pdp6 -S \
    "$here/marker-v1369.c" -o "$work/marker-v1369.s"
"$das" -F -C -O "$work/marker-v1369.dobj" "$work/marker-v1369.s"
"$dlink" -b 020 -o "$work/marker-v1369.dxr" \
    -M "$work/marker-v1369.map" "$work/marker-v1369.dobj"
test -s "$boot/tape-mres.dxr" || {
    echo 'v1369: build the full PDP-6 KCORE/MRES DXR inventory first' >&2
    exit 1
}

# Never overwrite normal artifacts. All grouped DXRs have explicit
# versioned names and are independently decoded before publication.
for stem in marker tape; do
    case "$stem" in
        marker) original="$work/marker-v1369.dxr" ;;
        tape) original="$boot/tape-mres.dxr" ;;
    esac
    output="$work/$stem.grouped-v1369.dxr"
    rm -f "$output"
    python3 -B "$here/grouped_dxr_v1369.py" "$original" "$output"
done

# Verify the producer rejects an already-compressed image without
# publishing a partial or legacy-named file.
if python3 -B "$here/grouped_dxr_v1369.py" \
    "$work/marker.grouped-v1369.dxr" \
    "$work/rejected-already-compressed-v1369.dxr" \
    > "$work/rejected-already-compressed-v1369.log" 2>&1; then
    echo 'v1369: producer accepted an already compressed image' >&2
    exit 1
fi
test ! -f "$work/rejected-already-compressed-v1369.dxr"

# Alias the existing caller-visible ABI *only in this test*. Real
# EXEC/PURE/TSFS assembler source files are linked unchanged.
sed -e 's/d6codec_decode_vfs_v1367/d6lz36_decode_vfs/g' \
    -e 's/d6codec_decode_buffer_v1367/d6lz36_decode_buffer/g' \
    "$core/core/d6codec_vfs_v1367.s" > "$work/decoder-alias-v1369.s"

for stem in marker tape; do
    case "$stem" in
        marker) original="$work/marker-v1369.dxr" ;;
        tape) original="$boot/tape-mres.dxr" ;;
    esac
    fixture="$work/$stem-exec-native-v1369.s"
    pure="$work/$stem-pure-native-v1369.s"
    python3 -B "$here/generate_exec_native_v1369.py" \
        "$original" "$work/$stem.grouped-v1369.dxr" "$fixture" \
        "$core/proc/proc_pure_backing_pdp6.s" "$pure"
    "$runner" --machine pdp6 --mode deposit --exec-mode go \
        --start 1000 --timeout 50 \
        --workdir "$work/$stem-exec-native" \
        --name "d6codec-exec-$stem-v1369" --expect __test_exit=0 \
        "$testkit/tests/validation/daimos-test-crt0-v1.s" \
        "$fixture" "$core/proc/exec_load.s" "$pure" \
        "$work/decoder-alias-v1369.s" \
        "$core/core/d6codec_stream_v1367.s" "$here/kconst-v1369.s"
done

# The real TSFS read/copy/free code consumes one-block grouped restart
# extents and cleans up transient MM allocations after either result.
for kind in good bad; do
    fixture="$work/tsfs-$kind-v1369.s"
    python3 -B "$here/generate_tsfs_native_v1369.py" \
        "$testkit/tests/validation/daimos-tsfs-d6lz-v1.s" \
        "$fixture" "$kind"
    "$runner" --machine pdp6 --mode deposit --exec-mode go \
        --start 1000 --timeout 40 \
        --workdir "$work/tsfs-$kind" \
        --name "d6codec-tsfs-$kind-v1369" --expect __test_exit=0 \
        "$testkit/tests/validation/daimos-test-crt0-v1.s" \
        "$fixture" "$core/fs/tsfs_runtime.s" \
        "$work/decoder-alias-v1369.s" \
        "$core/core/d6codec_stream_v1367.s" "$here/kconst-v1369.s"
done

echo 'PASS v1369: compiled grouped EXEC, actual PURE reload, actual TSFS restart and failure rollback'
