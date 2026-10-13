#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 80 --workdir "$TMPDIR/d6codec-v049-dsh" \
 --name d6codec-v049-dsh --expect __test_exit=0 \
 "$root/tests/validation/daimos-test-crt0-v1.s" \
 "$root/tests/validation/d6codec-native-v049/test_full_dsh_v049.s" \
 "$root/tests/validation/d6codec-native-v049/encode_v049.s" \
 "$root/tests/validation/d6codec-native-v049/decode_v049.s"
