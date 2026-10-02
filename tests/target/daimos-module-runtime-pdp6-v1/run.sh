#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/daimos-testkit-module-runtime-pdp6-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
p10run="$PDP10_PREFIX/bin/p10run"
kernel="$DAIMOS_REPO/system/kernel"
"$cc" -std=c99 -Os -I"$PDP10_PREFIX/include" -I"$kernel/modules" -I"$kernel/core" \
    -I"$kernel/fs" -I"$kernel/mm" -I"$kernel/storage" -S "$here/test.c" \
    -o "$work/test.s"
"$cc" -std=c99 -Os -I"$PDP10_PREFIX/include" -I"$kernel/modules" -I"$kernel/core" \
    -I"$kernel/fs" -I"$kernel/mm" -I"$kernel/storage" \
    -S "$kernel/modules/module_runtime.c" \
    -o "$work/module_runtime.c.s"
cat "$work/module_runtime.c.s" "$kernel/modules/module_runtime_pdp6.s" \
    > "$work/module_runtime.s"
PDP10_PREFIX="$PDP10_PREFIX" "$p10run" \
    --machine pdp6 --mode deposit --exec-mode go --timeout 10 \
    --workdir "$work/run" --name daimos-module-runtime-pdp6-v1 \
    --expect daimos_module_runtime_pdp6_result=0 --report "$work/report.txt" \
    "$here/start.s" "$work/test.s" "$work/module_runtime.s" "$here/stubs.s"
