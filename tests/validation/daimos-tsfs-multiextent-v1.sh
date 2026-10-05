#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-tsfs-multiextent-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
cat > "$work/kconst.s" <<'ASM'
        .data
        .globl kconst_1_1
        .globl kconst_2_2
        .globl kconst_5_5
        .globl kconst_7_7
kconst_1_1: .word 1,,1
kconst_2_2: .word 2,,2
kconst_5_5: .word 5,,5
kconst_7_7: .word 7,,7
ASM
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 20 --workdir "$work/run" --name daimos-tsfs-multiextent \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-tsfs-multiextent-v1.s" \
    "$DAIMOS_REPO/system/kernel/fs/tsfs_runtime.s" \
    "$work/kconst.s" >/dev/null
printf '%s\n' 'daimos-tsfs-multiextent-v1: PASS (cross-extent, cross-member read)'
