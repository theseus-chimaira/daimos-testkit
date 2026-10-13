#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 25 --workdir "$TMPDIR/d6codec-v046-darc-256" \
 --name d6codec-v046-darc-256 --expect __test_exit=0 \
 "$root/tests/validation/daimos-test-crt0-v1.s" \
 "$root/tests/validation/d6codec-native-v046/test_darc_256_v046.s" \
 "$root/tests/validation/d6codec-native-v046/encode_v046.s" \
 "$root/tests/validation/d6codec-native-v046/decode_v046.s"
