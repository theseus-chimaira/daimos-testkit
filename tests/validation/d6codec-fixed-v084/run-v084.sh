#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
export PDP10_PREFIX TMPDIR
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# Keep BLT source/end symbols inside one assembler unit: cross-object
# symbol differences cannot be evaluated by the DAIMOS fixed-address linker.
mkdir -p "$TMPDIR/d6codec-fixed-v084"
awk '/^\.data$/ { exit } { print }' "$base/test-v084.s" \
    > "$TMPDIR/d6codec-fixed-v084/combined-v084.s"
cat "$DAIMOS_REPO/system/stand/pdp6/common/decompressor.inc" \
    >> "$TMPDIR/d6codec-fixed-v084/combined-v084.s"
awk '/^\.data$/ { copy=1 } copy { print }' "$base/test-v084.s" \
    >> "$TMPDIR/d6codec-fixed-v084/combined-v084.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 20 --workdir "$TMPDIR/d6codec-fixed-v084" \
 --name d6codec-fixed-v084 --expect __test_exit=0 \
 "$base/../../validation/daimos-test-crt0-v1.s" \
 "$TMPDIR/d6codec-fixed-v084/combined-v084.s"
