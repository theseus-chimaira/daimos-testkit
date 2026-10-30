#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-backstore-free-v777.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
 echo '.text'
 echo '.globl backstore_free'
 sed -n '/^backstore_free:$/,/^        \.bss/p' "$DAIMOS_REPO/system/kernel/storage/backstore.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" \
 --name daimos-backstore-free-v777 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
 "$self/daimos-backstore-free-bounds-v777.s" > "$work/result.log" 2>&1 || {
 tail -30 "$work/result.log" >&2; exit 1;
 }
echo 'v777: native PDP-6 BACKSTORE free bounds PASS'
