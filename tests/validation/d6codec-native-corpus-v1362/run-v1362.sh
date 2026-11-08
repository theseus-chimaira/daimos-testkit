#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-native-corpus-v1362"
mkdir -p "$work"
python3 "$testkit/tests/validation/d6codec-current-corpus-v1359/generate-v1359.py" \
  "$DAIMOS_REPO/build/system/boot/pdp6" "$work" >/dev/null
for kind in kcore d6fs-mres monitorfs-mres swap-mres-v481 tape-mres; do
  for width in 1 7 64; do
    fixture="$work/native_${kind}_window_${width}_v1362.s"
    python3 "$testkit/tests/validation/d6codec-native-stream-v1361/generate_dxr_v1361.py" \
      "$work/native_${kind}_v1359.s" "$fixture" "$width"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
      --exec-mode go --start 1000 --timeout 30 \
      --workdir "$work/run_${kind}_${width}" \
      --name "d6codec-native-${kind}-${width}-v1362" --expect __test_exit=0 \
      "$testkit/tests/validation/daimos-test-crt0-v1.s" \
      "$fixture" \
      "$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1361.s"
  done
done
echo 'PASS v1362 native current DXR prefixes: five categories x three windows'
