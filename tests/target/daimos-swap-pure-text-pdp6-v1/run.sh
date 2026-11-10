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
    "$cc" -std=c99 -Os ${EXTRA_TEST_FLAGS:-} $extra \
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
        -I"$kernel/core" -I"$kernel/drivers" -I"$kernel/fs" -I"$kernel/mm" \
        -I"$kernel/modules" -I"$kernel/proc" -I"$kernel/storage" \
        -S "$kernel/proc/vm_pdp6_swap.c" -o "$work/swap-c-$mode.s"
    {
        cat "$work/swap-c-$mode.s"
        echo ".equ PROC_SWAP_VERIFY_PURE,$verify"
        # Match the production swap transaction implementation exactly.
        # Modern proc_swap_pdp6.s also contains separate two-process
        # exchange orchestration, which needs unrelated MM service leaves.
        # This target tests actual PURE swap out/in, not exchange. Retain
        # the production constants and native transaction bodies, without
        # adding unused exchange dependencies or fake successful stubs.
        # Export only transaction entries: the original file declares
        # MRES service globals that are not linked in this target fixture.
        printf '.text\n.globl proc_swap_out\n.globl proc_swap_in\n'
        sed -n '/^[[:space:]]*\.equ[[:space:]]/p' \
            "$kernel/proc/proc_swap_pdp6.s"
        sed -n '/^proc_swap_skip_words:$/,/^proc_swap_mres_service_v481:$/p' \
            "$kernel/proc/proc_swap_pdp6.s" | sed '$d'
        cat "$kernel/proc/proc_swap_entry_v481.s" \
            "$kernel/proc/proc_pure_backing_pdp6.s" \
            "$kernel/proc/proc_storage_runtime_v30.s"
        # Keep the real read-only verifier used by the C detach path.
        printf '.text\n.globl backstore_verify_allocated_v795\n'
        sed -n '/^backstore_verify_allocated_v795:$/,/^; int backstore_extend(first,old_blocks,new_blocks)/p' \
            "$kernel/storage/backstore.s" | sed '$d'
        # The production optional PURE verifier uses the SWAP-MRES-owned
        # scratch sector, not the filesystem's potentially busy DMA buffer.
        # Include that exact production BSS leaf only in the verify image.
        if [ "$verify" = 1 ]; then
            printf '.bss\n.globl proc_swap_sector_buffer_v1237\n'
            sed -n '/^proc_swap_sector_buffer_v1237:$/,/^        \.text$/p' \
                "$kernel/proc/proc_swap_pdp6.s" | sed '$d'
            printf '.text\n'
        fi
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
