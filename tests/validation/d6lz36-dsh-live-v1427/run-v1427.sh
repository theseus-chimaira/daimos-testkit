#!/bin/sh
# Host encode + exact PDP-6 decoder and instruction-step comparison.
set -eu
: "${DAIMOS_REPO:?point at isolated DAIMOS v1426 worktree}"
PDP10_PREFIX=${PDP10_PREFIX:-"$HOME/cross"}
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export PDP10_PREFIX TMPDIR
here=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6lz36-dsh-live-v1427"
captured="$TMPDIR/d6codec-shell-live-v1426"
mkdir -p "$work"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic -fPIC -shared \
    "$DAIMOS_REPO/tools/host/d6lz-codec.c" \
    -o "$work/libd6lz36-v1427.so"
python3 -B "$here/tests/validation/d6lz36-dsh-live-v1427/compare-v1427.py" \
    --input "$captured" --library "$work/libd6lz36-v1427.so" \
    --output "$work" --native-fixtures
for state in idle_initial after_commands after_function; do
    name="$state-d6lz36-verify-v1427"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 50 \
        --workdir "$work/run-$name" --name "$name" \
        --expect __test_exit=0 \
        "$here/tests/validation/daimos-test-crt0-v1.s" \
        "$work/$name.s" \
        "$DAIMOS_REPO/system/kernel/core/d6lz_pdp6.s" \
        "$DAIMOS_REPO/system/stand/pdp6/common/decompressor.inc"
done
python3 -B "$here/tests/validation/d6lz36-dsh-live-v1427/measure-speed-v1427.py" \
    --work "$work" --testkit "$here" --daimos "$DAIMOS_REPO" \
    --pdp10-prefix "$PDP10_PREFIX"
