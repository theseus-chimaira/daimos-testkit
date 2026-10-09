#!/bin/sh
# Test the host makedepend graph without changing tracked source timestamps.
set -eu
: "${TMPDIR:=$HOME/tmp}"
root=$(CDPATH= cd -- "$(dirname "$0")/../../../kcc" && pwd)
make -C "$root" depend
f="$root/build/depend.mk"
test -s "$f"
grep -q '^build/cc.o build/cc.s: cc.c$' "$f"
grep -q '^build-native/ccdata-gen.s: ccdata.c$' "$f"
grep -q '^build-native/ccdata-parse.s: ccdata.c$' "$f"
grep -q '^build-native/ccdata-cpp.s: ccdata.c$' "$f"
if grep -q '^build-native/ccdata-gen.s: /usr/include' "$f"; then
    echo 'native dependency scanner leaked host /usr/include' >&2
    exit 1
fi
printf 'PASS: host and native KCC dependency graph\n'
