# K17.1: common low-core relocation v1961

Source-matched PDP-6 KCC builds with KCORE and the shared block decoder
at octal 062. The five Stage1 read-in entry addresses remain octal 060.
The test checks the 53-word core in all five DXR1 images, forward BLT
safety (including the overlapping MTC source), post-copy handoff and
error labels, and the complete KCORE embedding in KINIT.

Build two disposable images using the current DAIMOS source:

    TMPDIR=${TMPDIR:-$HOME/tmp}
    export TMPDIR
    w=$(mktemp -d "$TMPDIR/k17-lowcore-v1961.XXXXXX")
    make -C "$DAIMOS_REPO/system/boot/pdp6" image BUILD="$w/full" \
        ROOT=tape BOOT=dtc COMPILER=kcc BOOT_PROFILE=full \
        SIMH_CPU_KWORDS=256 BOOT_CORE_WORDS=01000000 TSFS_ROOT_MEMBERS=3
    make -C "$DAIMOS_REPO/system/boot/pdp6" image BUILD="$w/lowmem" \
        ROOT=tape BOOT=dtc COMPILER=kcc BOOT_PROFILE=lowmem \
        SIMH_CPU_KWORDS=64 BOOT_CORE_WORDS=0200000 TSFS_ROOT_MEMBERS=3 \
        TSFS_INPLACE_BOOT=1

From this test directory:

    python3 -B verify-v1961.py "$DAIMOS_REPO" "$PDP10_PREFIX/bin/das" \
        "$w/full" "$w/verify-full"
    python3 -B verify-v1961.py "$DAIMOS_REPO" "$PDP10_PREFIX/bin/das" \
        "$w/lowmem" "$w/verify-lowmem"
    python3 -B native-v1961.py "$w/full" "$w/lowmem" \
        "$w/native" "$PDP10_PREFIX"

Native tests copy DECtape media, detach auxiliary devices, disable host
video, and retain readbacks/logs. Compressed boot stops at KINIT entry;
64K hybrid raw boot stops at the first INIT V1 output. Both independently
compare all 53 physical decoder words against the linked KCORE stream.
This is not a full login/process-pressure test or KA10 acceptance.

The updated d6codec-fixed-v1458 component harness exercises the shared
core and VFS adapter including sentinel words at 060 and 061. Its
full-DXR corpus needs a source-matched D6FS MRES built separately with
ROOT=auto when the tape-only image omits D6FS. The remaining payloads
are the current KCORE, monitorfs, swap, tape MRES and DSH DXRs.
