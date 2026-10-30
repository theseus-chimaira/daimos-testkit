#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-storage-exchange-v778.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" \
 --name daimos-storage-exchange-v778 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" \
 "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" \
 "$self/daimos-storage-exchange-native-v778.s" > "$work/result.log" 2>&1 || {
 tail -35 "$work/result.log" >&2; exit 1;
 }
echo 'v778: native PDP-6 storage mode pair PASS'
