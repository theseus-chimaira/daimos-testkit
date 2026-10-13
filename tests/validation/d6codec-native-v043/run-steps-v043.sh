#!/bin/sh
set -eu
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
for k in configctl darc d6lz; do
 for kind in group singleton; do
  for n in 35000 40000 45000 50000 55000; do
   ident="d6codec-v043-${k}-${kind}-${n}"
   "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --step-limit "$n" --start 1000 --timeout 15 --workdir "$TMPDIR/$ident" \
    --name "$ident" --expect __test_exit=0 \
    "$root/tests/validation/daimos-test-crt0-v1.s" \
    "$root/tests/validation/d6codec-native-v042/test_${k}_${kind}_v042.s" \
    "$root/tests/validation/d6codec-native-v042/encode_${kind}_v042.s" >/dev/null 2>&1 || :
   printf '%s\t%s\t%s\t' "$k" "$kind" "$n"
   sed -n 's/^result=//p' "$TMPDIR/$ident/$ident.report.txt"
  done
 done
done
