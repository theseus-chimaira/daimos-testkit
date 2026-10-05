#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
kernel="$DAIMOS_REPO/system/kernel"
work="$TMPDIR/daimos-dtfs-chain-walk-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c89 -Os -fno-builtin -fno-common \
        -march=pdp6 -S "$self/daimos-dtfs-chain-walk-v1.c" -o "$work/oracle.s"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 5000000 --timeout 20 \
        --workdir "$work/run" --name daimos-dtfs-chain-walk-v1 \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$work/oracle.s" \
        "$kernel/fs/dtfs_chain_walk.s" "$kernel/core/ret.s" >/dev/null
printf '%s\n' 'dtfs-chain-walk: PASS (NATIVE/TENEX/ITS production PDP-10 chain/census paths)'
