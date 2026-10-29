#!/bin/sh
# Switching KINIT diagnostic flags in one build must rebuild BOTH source
# outputs: compiler-generated kinit.s and assembler kinit_io_pdp6.s.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-mode-v655.XXXXXX")
passed=0
cleanup()
{
    if [ "$passed" -eq 1 ]; then
        rm -rf "$work"
    else
        echo "v655: KINIT-mode build diagnostics retained at $work" >&2
    fi
}
trap cleanup EXIT HUP INT TERM
build=$work/kinit-asm
if [ -n "${DAIMOS_KINIT_MODE_SEED_V655:-}" ]; then
    cp -a "$DAIMOS_KINIT_MODE_SEED_V655" "$build"
fi
make_kinit()
{
    mode=$1
    PATH="$PDP10_PREFIX/bin:$PATH" make -s \
        -C "$DAIMOS_REPO/system/kernel" kinit BUILD="$build" \
        PDP10_PREFIX="$PDP10_PREFIX" COMPILER=gcc \
        KINIT_STACK_WATERMARK="$mode" KINIT_STACK_RESERVE_WORDS=0400 \
        KINIT_FULL=1 KINIT_DRM_ENABLED=1 KINIT_TAPE_BOOT=1 \
        KINIT_BADMAP=1 D6FS_FS_ENABLED=1 BLOCKSET_FS_ENABLED=1 \
        MONITORFS_MRES_ENABLED=1 PROC_BOOT_USERS=1 \
        PROC_STACK_WATERMARK=0 VM_BACKEND=pdp6 \
        >> "$work/build.log" 2>&1 || {
            tail -40 "$work/build.log" >&2
            return 1
        }
}
verify_mode()
{
    mode=$1
    grep -Fqx ".set KINIT_STACK_WATERMARK,$mode" \
        "$build/kinit_io_pdp6.s"
    grep -Fqx '.set KINIT_STACK_RESERVE_WORDS,0400' \
        "$build/kinit_io_pdp6.s"
    if [ "$mode" -eq 1 ]; then
        grep -Eq 'pushj[[:space:]]+17,kinit_stack_watermark_begin' \
            "$build/kinit.s"
    else
        if grep -Eq 'pushj[[:space:]]+17,kinit_stack_watermark_begin' \
            "$build/kinit.s"; then
            echo 'v655: watermark-disabled C still contains stack probes' >&2
            return 1
        fi
    fi
}
for mode in 1 0 1; do
    make_kinit "$mode"
    verify_mode "$mode"
done
passed=1
echo 'daimos-kinit-mode-invalidation-v655: PASS (watermark 1 -> 0 -> 1, reserve 0400)'
