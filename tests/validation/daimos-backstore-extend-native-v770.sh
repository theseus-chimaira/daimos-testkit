#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-bstore-extend-v770.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel/storage/backstore.s"
{
 echo '.text'
 echo '.globl backstore_extend'
 sed -n '/^backstore_extend:$/,/^; void backstore_free/p' "$src" | sed '$d'
} > "$work/extend.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" \
 --name daimos-backstore-extend-v770 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/extend.s" \
 "$self/daimos-backstore-extend-native-v770.s" > "$work/result.log" 2>&1 || {
 tail -35 "$work/result.log" >&2; exit 1;
 }
echo 'v770: native PDP-6 BACKSTORE contiguous extension PASS'
