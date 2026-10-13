#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 30 --workdir "$TMPDIR/d6codec-v052-abi" \
 --name d6codec-v052-abi --expect __test_exit=0 \
 "$root/tests/validation/daimos-test-crt0-v1.s" \
 "$root/tests/validation/d6codec-native-v052/test_kernel_abi_v052.s" \
 "$root/tests/validation/d6codec-native-v052/wrapper_v052.s" \
 "$root/tests/validation/d6codec-native-v052/encode_v052.s" \
 "$root/tests/validation/d6codec-native-v052/decode_v052.s"
