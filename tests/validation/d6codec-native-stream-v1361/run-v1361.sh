#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
mkdir -p "$TMPDIR/d6codec-native-stream-v1361"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 30 \
  --workdir "$TMPDIR/d6codec-native-stream-v1361/run" \
  --name d6codec-native-stream-v1361 --expect __test_exit=0 \
  "$root/tests/validation/daimos-test-crt0-v1.s" \
  "$root/tests/validation/d6codec-native-stream-v1361/test_stream_v1361.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1361.s"

# Current KCORE payload generated with the independent host stream
# encoder used by the v1359 corpus suite. Exercise word-size refills.
corpus="$TMPDIR/d6codec-current-corpus-v1359"
mkdir -p "$corpus"
python3 "$root/tests/validation/d6codec-current-corpus-v1359/generate-v1359.py" \
  "$DAIMOS_REPO/build/system/boot/pdp6" "$corpus" >/dev/null
python3 "$root/tests/validation/d6codec-native-stream-v1361/generate_dxr_v1361.py" \
  "$corpus/native_kcore_v1359.s" \
  "$TMPDIR/d6codec-native-stream-v1361/test_kcore_v1361.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 45 \
  --workdir "$TMPDIR/d6codec-native-stream-v1361/kcore" \
  --name d6codec-stream-kcore-v1361 --expect __test_exit=0 \
  "$root/tests/validation/daimos-test-crt0-v1.s" \
  "$TMPDIR/d6codec-native-stream-v1361/test_kcore_v1361.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1361.s"
