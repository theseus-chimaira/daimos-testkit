#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for spec in darc:group:30000 darc:group:40000 darc:singleton:40000 darc:singleton:50000 configctl:group:50000 configctl:singleton:50000 d6lz:group:50000 d6lz:singleton:50000; do
 k=${spec%%:*}; x=${spec#*:}; kind=${x%%:*}; n=${x##*:}; ident="d6codec-v042-${k}-${kind}-${n}"
 "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --step-limit "$n" --start 1000 --timeout 15 --workdir "$TMPDIR/$ident" \
 --name "$ident" --expect __test_exit=0 \
 "$root/tests/validation/daimos-test-crt0-v1.s" \
 "$root/tests/validation/d6codec-native-v042/test_${k}_${kind}_v042.s" \
 "$root/tests/validation/d6codec-native-v042/encode_${kind}_v042.s" > /dev/null 2>&1 || :
 printf '%s ' "$spec"
 grep 'result=' "$TMPDIR/$ident/$ident.report.txt"
done
