#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/daimos-swap-pure-text-pdp6-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
p10run="$PDP10_PREFIX/bin/p10run"
kernel="$DAIMOS_REPO/system/kernel"
decoder="$DAIMOS_REPO/system/stand/pdp6/common/decompressor.inc"

cat >"$work/decoder.s" <<EOF_ASM
        .text
        .globl  install_d6lz_decoder
install_d6lz_decoder:
        movei   1,d6lz_image_start
        hrl     1,1
        hrri    1,d6lz_fixed_base
        blt     1,d6lz_fixed_base+(d6lz_image_end-d6lz_image_start)-1
        popj    17,
        .include "$decoder"
EOF_ASM

compile_test()
{
    mode=$1
    extra=$2
    "$cc" -std=c99 -Os $extra \
        -I"$PDP10_PREFIX/include" \
        -I"$kernel/core" -I"$kernel/fs" -I"$kernel/mm" \
        -I"$kernel/proc" -I"$kernel/storage" \
        -S "$here/test.c" -o "$work/test-$mode.s"
}

compile_swap()
{
    mode=$1
    verify=$2
    "$cc" -std=c99 -Os -DPROC_SWAP_TRANSACTIONS_PDP6_ASM=1 \
        -DPROC_SWAP_SERVICE_PDP6_ASM=1 -DPROC_SWAP_RECLAIM_PDP6_ASM=1 \
        -DPROC_SWAP_VERIFY_PURE="$verify" \
        -I"$PDP10_PREFIX/include" \
        -I"$kernel/core" -I"$kernel/drivers" -I"$kernel/fs" -I"$kernel/mm" \
        -I"$kernel/modules" -I"$kernel/proc" -I"$kernel/storage" \
        -S "$kernel/proc/vm_pdp6_swap.c" -o "$work/swap-c-$mode.s"
    {
        cat "$work/swap-c-$mode.s"
        echo ".equ PROC_SWAP_VERIFY_PURE,$verify"
        cat "$kernel/proc/proc_swap_pdp6.s"
    } >"$work/swap-$mode.s"
}

compile_test normal ""
compile_swap normal 0

PDP10_PREFIX="$PDP10_PREFIX" "$p10run" \
    --machine pdp6 --mode deposit --exec-mode go --timeout 10 \
    --workdir "$work/run" --name daimos-swap-pure-text-pdp6-v1 \
    --expect daimos_swap_pure_text_pdp6_result=0 --report "$work/report.txt" \
    "$here/start.s" "$work/test-normal.s" "$here/stubs.s" "$work/swap-normal.s" \
    "$kernel/core/d6lz_pdp6.s" "$work/decoder.s" "$kernel/core/ret.s"

compile_test verify "-DTEST_VERIFY_PURE=1"
compile_swap verify 1

PDP10_PREFIX="$PDP10_PREFIX" "$p10run" \
    --machine pdp6 --mode deposit --exec-mode go --timeout 10 \
    --workdir "$work/run-verify" --name daimos-swap-pure-verify-pdp6-v1 \
    --expect daimos_swap_pure_text_pdp6_result=1 \
    --report "$work/report-verify.txt" \
    "$here/start.s" "$work/test-verify.s" "$here/stubs.s" "$work/swap-verify.s" \
    "$kernel/core/d6lz_pdp6.s" "$work/decoder.s" "$kernel/core/ret.s"

printf '%s\n' "daimos-swap-pure-text-pdp6-v1: PASS (raw/compressed PURE suffix swap, backing pinning, non-PURE full swap, verifier assertion)"
