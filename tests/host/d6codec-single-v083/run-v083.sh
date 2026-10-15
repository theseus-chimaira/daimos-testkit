#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${INPUT_DXR:?Set INPUT_DXR to an uncompressed executable}"
: "${TMPDIR:=$HOME/tmp}"
work="$TMPDIR/d6codec-single-v083"
mkdir -p "$work"
make -C "$DAIMOS_REPO/tools/host" BUILD_ROOT="$work" "$work/tools/host/d6lz"
"$work/tools/host/d6lz" -x "$INPUT_DXR" "$work/compressed.dxr"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
 -I"$DAIMOS_REPO/tools/host" "$(dirname "$0")/check-v083.c" \
 "$DAIMOS_REPO/tools/host/d6codec-group-v071.c" -o "$work/check"
"$work/check" "$INPUT_DXR" "$work/compressed.dxr"
