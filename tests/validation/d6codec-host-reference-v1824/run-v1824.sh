#!/bin/sh
# Compile and compare the current DAIMOS host block codec, never a mock.
set -eu
: "${TMPDIR:=$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${DAIMOS_BUILD_DXR_DIR:=$DAIMOS_REPO/build/system/boot/pdp6}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-d6block-host-v1824.XXXXXX")
if [ "${D6BLOCK_HOST_KEEP_V1824:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -fPIC -shared \
    -o "$work/host-block-v1824.so" \
    "$DAIMOS_REPO/tools/host/d6block-codec-v1452.c"
python3 -B "$here/check-host-v1824.py" \
    --boot "$DAIMOS_BUILD_DXR_DIR" \
    --library "$work/host-block-v1824.so"
