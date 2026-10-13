#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for kind in main hidden literals boundary capacity capacity_exact capacity_tight dxr_configctl dxr_darc dxr_d6lz; do
  "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 15 --workdir "$TMPDIR/d6codec-v041-$kind" \
  --name "d6codec-v041-$kind" --expect __test_exit=0 \
  "$root/tests/validation/daimos-test-crt0-v1.s" \
  "$root/tests/validation/d6codec-native-v041/test_${kind}_v041.s" \
  "$root/tests/validation/d6codec-native-v041/encode_v041.s" \
  "$root/tests/validation/d6codec-native-v041/decode_v041.s"
done
