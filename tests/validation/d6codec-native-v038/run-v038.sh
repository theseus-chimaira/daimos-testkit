#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for kind in configctl darc d6lz; do
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
 --exec-mode go --start 1000 --timeout 15 \
 --workdir "$TMPDIR/d6codec-v038-$kind" \
 --name "d6codec-v038-$kind" --expect __test_exit=0 \
 "$root/tests/validation/daimos-test-crt0-v1.s" \
 "$root/tests/validation/d6codec-native-v038/test_${kind}_v038.s" \
 "$root/tests/validation/d6codec-native-v038/encode_baseline_v038.s" \
 "$root/tests/validation/d6codec-native-v038/encode_cursor_v038.s"
done
