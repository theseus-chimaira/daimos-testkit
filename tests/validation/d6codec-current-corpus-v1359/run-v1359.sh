#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-current-corpus-v1359"
mkdir -p "$work"
python3 "$testkit/tests/validation/d6codec-current-corpus-v1359/generate-v1359.py" \
  "$DAIMOS_REPO/build/system/boot/pdp6" "$work"
for kind in kcore d6fs-mres monitorfs-mres swap-mres-v481 tape-mres; do
  "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 45 --workdir "$work/run_$kind" \
    --name "d6codec-current-$kind-v1359" --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/native_${kind}_v1359.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_kcore_abi_v055.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_encode_v053.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_decode_v053.s"
done
