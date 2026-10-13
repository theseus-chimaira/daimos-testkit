#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for kind in configctl darc d6lz; do
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 45 --workdir "$TMPDIR/d6codec-v047-${kind}-full" \
 --name "d6codec-v047-${kind}-full" --expect __test_exit=0 \
 "$root/tests/validation/daimos-test-crt0-v1.s" \
 "$root/tests/validation/d6codec-native-v047/test_full_${kind}_v047.s" \
 "$root/tests/validation/d6codec-native-v047/encode_v047.s" \
 "$root/tests/validation/d6codec-native-v047/decode_v047.s"
done
