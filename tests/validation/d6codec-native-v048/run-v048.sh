#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for testfile in "$root"/tests/validation/d6codec-native-v048/test_*_v048.s; do
 name=${testfile##*/};name=${name#test_};name=${name%_v048.s}
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 15 --workdir "$TMPDIR/d6codec-v048-$name" \
 --name "d6codec-v048-$name" --expect __test_exit=0 \
 "$root/tests/validation/daimos-test-crt0-v1.s" "$testfile" \
 "$root/tests/validation/d6codec-native-v048/decode_v048.s"
done
