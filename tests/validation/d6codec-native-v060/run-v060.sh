#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 15 --workdir "$TMPDIR/d6codec-v060-odd" \
 --name d6codec-v060-odd --expect __test_exit=0 \
 "$testkit/tests/validation/daimos-test-crt0-v1.s" \
 "$testkit/tests/validation/d6codec-native-v060/test_odd_overlap_v060.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_decode_v059.s"

# Re-run the existing invalid-stream fixtures against the v059 decoder.
mkdir -p "$TMPDIR/d6codec-v060-legacy-regressions"
for fixture in $testkit/tests/validation/d6codec-native-v048/test_*_v048.s; do
 name=${fixture##*/}
 sed 's/d6v048_decode/d6codec_v059_decode/g' "$fixture" > "$TMPDIR/d6codec-v060-legacy-regressions/$name"
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 15 --workdir "$TMPDIR/d6codec-v060-legacy-regressions/$name-run" \
  --name "d6codec-v060-$name" --expect __test_exit=0 \
  $testkit/tests/validation/daimos-test-crt0-v1.s \
  "$TMPDIR/d6codec-v060-legacy-regressions/$name" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_decode_v059.s"
done
