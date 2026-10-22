#!/bin/sh
# Ensure the installed host optimizer rejects unsafe GE status-skip folding.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:=$HOME/tmp}"
work="$TMPDIR/daimos-installed-p10fold-ge-v164-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
"$PDP10_PREFIX/bin/das" -F -C -O "$work/ge.dobj" \
    "$DAIMOS_REPO/system/kernel/drivers/ge_io.s"
"$PDP10_PREFIX/bin/p10fold" -m 2 -P "$work/ge.fold" \
    "$work/ge.dobj" > "$work/analysis.txt"
grep -qx 'P10FOLD1' "$work/ge.fold"
if grep -q '^FOLD' "$work/ge.fold"; then
    echo 'installed-p10fold-ge-v164: unsafe GE skip/JRST fold detected' >&2
    cat "$work/ge.fold" >&2
    exit 1
fi
echo 'installed-p10fold-ge-v164: PASS'
