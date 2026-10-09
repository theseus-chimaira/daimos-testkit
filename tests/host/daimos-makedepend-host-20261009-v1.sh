#!/bin/sh
set -eu
: "${TMPDIR:=$HOME/tmp}"
root=$(CDPATH= cd -- "$(dirname "$0")/../../../DAIMOS" && pwd)
out="$TMPDIR/daimos-makedepend-host-20261009-v1"
mkdir -p "$out"
make -C "$root/userland/makedepend" host BUILD="$out"
cat > "$out/sample.h" <<'HEADER'
#define DAIMOS_MAKEDEPEND_TEST 1
HEADER
cat > "$out/sample.c" <<'SOURCE'
#include "sample.h"
int sample(void) { return DAIMOS_MAKEDEPEND_TEST; }
SOURCE
(cd "$out" && ./makedepend -f- sample.c > deps.mk)
grep -q 'sample.o: sample.h' "$out/deps.mk"
printf 'PASS: makedepend host reference tracks local headers\n'
