#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR/d6codec-encode-bounds-v1354"
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 30 \
  --workdir "$TMPDIR/d6codec-encode-bounds-v1354/run" \
  --name d6codec-encode-bounds-v1354 --expect __test_exit=0 \
  "$testkit/tests/validation/daimos-test-crt0-v1.s" \
  "$testkit/tests/validation/d6codec-encode-bounds-v1354/test_encode_bounds_v1354.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_kcore_abi_v055.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_encode_v053.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_decode_v053.s"
