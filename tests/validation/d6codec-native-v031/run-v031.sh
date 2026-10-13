#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for kind in unique repeated; do
 for steps in 2000 5000 10000 20000 40000 60000; do
 name="d6codec-v031-${kind}-${steps}"
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
 --exec-mode step --start 1000 --step-limit "$steps" --timeout 15 \
 --workdir "$TMPDIR/$name" --name "$name" --expect __test_exit=0 \
 "$root/tests/validation/daimos-test-crt0-v1.s" \
 "$root/tests/validation/d6codec-native-v031/test_${kind}_v031.s" \
 "$root/tests/validation/d6codec-native-v031/encode_v031.s" >/dev/null 2>&1 || :
 printf '%s %s ' "$kind" "$steps"
 grep 'result=' "$TMPDIR/$name/$name.report.txt"
 done
done
