#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 30 --workdir "$TMPDIR/d6codec-v051-stack-darc" \
 --name d6codec-v051-stack-darc --expect __test_exit=0 \
 --examine __v051_first_changed \
 "$root/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
 "$root/tests/validation/d6codec-native-v051/test_darc_v051.s" \
 "$root/tests/validation/d6codec-native-v051/encode_v051.s" \
 "$root/tests/validation/d6codec-native-v051/decode_v051.s"
