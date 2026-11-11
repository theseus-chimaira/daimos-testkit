#!/bin/sh
# Source-linked PDP-6 DXR shared-loader pilot preserving current raw XIP.
# Nothing here is linked into the production kernel or swap provider.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
testkit=$(CDPATH= cd -- "$self/../../.." && pwd)
kernel="$DAIMOS_REPO/system/kernel/proc"
work="${EXEC_V1487_WORK:-$TMPDIR/daimos-exec-xip-shared-v1487}"
mkdir -p "$work"
python3 "$testkit/tests/validation/exec-image-cutover-v1388/make-candidate-v1388.py" \
    "$kernel/exec_load.s" "$work/old-candidate-v1487.s"
python3 "$self/make-candidate-v1487.py" \
    "$kernel/exec_load.s" "$work/old-candidate-v1487.s" \
    "$work/exec-candidate-v1487.s"

# The historical DXR test has no MEMFS provider. Refuse its XIP operation
# from a test-only mock so the test can still link and exercise all DXR
# positive and negative paths without reaching an unimplemented provider.
cat > "$work/provider-v1487.s" <<'ASM'
        .text
        .globl fs_provider_reg_call
        .globl d6codec_decode_vfs_v1458
        .globl d6lz36_decode_vfs
        .globl proc_swap_unpack_backing
fs_provider_reg_call:
        seto    1,
        popj    17,
; The v1388 test supplies a decoder with the same four-register ABI
; under its historical name. The real shared engine uses the v1458 ABI.
d6codec_decode_vfs_v1458:
        jrst    d6lz36_decode_vfs
; FULL backing is not exercised by the original DXR startup fixture.
proc_swap_unpack_backing:
        setz    1,
        setz    2,
        popj    17,
ASM
include="-I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/system/kernel/mm -I$PDP10_PREFIX/include"
python3 "$self/make-fixture-v1487.py" \
    "$testkit/tests/validation/exec-image-cutover-v1388/test-native-v1388.c" \
    "$work/test-native-v1487.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $include \
    -S "$work/test-native-v1487.c" \
    -o "$work/test-v1487.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name exec-image-cutover-v1487 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/exec-candidate-v1487.s" \
    "$kernel/exec_image_common_v1386.s" \
    "$work/provider-v1487.s" "$work/test-v1487.s"

# Isolated TEXT figures from the same compiled profile. A positive delta
# is an explicit pre-production RAM cost, NOT permission to grow KCORE.
as="$PDP10_PREFIX/bin/das"
dump="$PDP10_PREFIX/bin/pdp10-objdump"
"$as" -C -O "$work/original-v1487.dobj" "$kernel/exec_load.s"
"$as" -C -O "$work/candidate-v1487.dobj" "$work/exec-candidate-v1487.s"
"$as" -C -O "$work/shared-v1487.dobj" "$kernel/exec_image_common_v1386.s"
python3 "$self/report-v1487.py" \
    "$dump" "$work/original-v1487.dobj" \
    "$work/candidate-v1487.dobj" "$work/shared-v1487.dobj" \
    "$work/report-v1487.txt"
cat "$work/report-v1487.txt"
echo 'PASS v1487: shared DXR native regression and XIP-preserving candidate'
