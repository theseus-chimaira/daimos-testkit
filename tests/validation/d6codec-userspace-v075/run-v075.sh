#!/bin/sh
# Compile/link the staged opt-in -G userspace writer without a 32K boot.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
root="$TMPDIR/d6codec-userspace-v075"
make -C "$DAIMOS_REPO/userland" PDP10_PREFIX="$PDP10_PREFIX" \
 BUILD_ROOT="$root" "$root/userland/d6lz.dxr"
test -s "$root/userland/d6lz.dxr"
echo 'PASS d6codec-userspace-v075 build/link (no runtime claim)'
