#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
kernel="$DAIMOS_REPO/system/kernel"
storage="$kernel/storage"
work="$TMPDIR/daimos-logstore-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -O2 -fno-builtin -fno-common \
        -march=pdp6 -I"$kernel/core" -I"$kernel/drivers" -I"$kernel/fs" \
        -I"$kernel/mm" -I"$kernel/modules" -I"$kernel/proc" \
        -I"$kernel/storage" -S \
        "$self/daimos-logstore-v1.c" -o "$work/oracle.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -O2 -fno-builtin -fno-common \
        -march=pdp6 -I"$kernel/core" -I"$kernel/drivers" -I"$kernel/fs" \
        -I"$kernel/mm" -I"$kernel/modules" -I"$kernel/proc" \
        -I"$kernel/storage" -S "$storage/logstore.c" \
        -o "$work/logstore.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -O2 -fno-builtin -fno-common \
        -march=pdp6 -I"$kernel/core" -I"$kernel/drivers" -I"$kernel/fs" \
        -I"$kernel/mm" -I"$kernel/modules" -I"$kernel/proc" \
        -I"$kernel/storage" -S "$storage/logstore_drain.c" \
        -o "$work/logstore_drain.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -O2 -fno-builtin -fno-common \
        -march=pdp6 -I"$kernel/core" -I"$kernel/drivers" -I"$kernel/fs" \
        -I"$kernel/mm" -I"$kernel/modules" -I"$kernel/proc" \
        -I"$kernel/storage" -S "$storage/logstore_mtc_sink.c" \
        -o "$work/logstore_mtc_sink.s"

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 3000000 --timeout 20 \
        --workdir "$work/run" --name daimos-logstore-v1 \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$work/oracle.s" "$work/logstore.s" "$work/logstore_drain.s" \
        "$work/logstore_mtc_sink.s" >/dev/null

printf '%s\n' 'logstore-v1: PASS (recovery, torn state/record, loss, tape drain)'
