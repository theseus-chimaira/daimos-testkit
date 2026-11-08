#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-parity-v1358"
mkdir -p "$work"
for kind in configctl darc d6lz; do
  # Existing v045 expected streams were generated independently from
  # actual DXR payload words by the host Python token/pack reference.
  sed -e 's/d6v045_encode_literals/d6codec_kcore_encode_v055/g' \
      -e 's/d6v045_decode/d6codec_kcore_decode_v055/g' \
      "$testkit/tests/validation/d6codec-native-v045/test_dxr_${kind}_v045.s" \
      > "$work/test_${kind}_v1358.s"
  "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/run_${kind}" \
    --name "d6codec-parity-${kind}-v1358" --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/test_${kind}_v1358.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_kcore_abi_v055.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_encode_v053.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_decode_v053.s"
done
