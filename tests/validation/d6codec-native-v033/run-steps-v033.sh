#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for spec in unique:50000 unique:55000 repeated:2000 repeated:2500; do
 kind=${spec%%:*}; steps=${spec#*:}; name="d6codec-v033-$kind-$steps"
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --step-limit "$steps" --start 1000 --timeout 15 --workdir "$TMPDIR/$name" \
 --name "$name" --expect __test_exit=0 \
 "$root/tests/validation/daimos-test-crt0-v1.s" \
 "$root/tests/validation/d6codec-native-v033/test_${kind}_v033.s" \
 "$root/tests/validation/d6codec-native-v033/encode_v033.s" >/dev/null 2>&1 || :
 printf '%s ' "$spec"
 grep 'result=' "$TMPDIR/$name/$name.report.txt"
done
