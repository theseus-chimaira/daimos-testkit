# K17 native KA10 build and first INIT v1964

Build separately, with the installed dxrconvert from DAS c59787f and
SIMH from sims cec5436:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    w=$(mktemp -d "$TMPDIR/k17-ka10-v1964.XXXXXX")
    make -C "$DAIMOS_REPO/system/boot/pdp6" DAIMOS_MACHINE=ka10 \
        BUILD="$w/ka10" image
    make -C "$DAIMOS_REPO/system/boot/pdp6" DAIMOS_MACHINE=pdp6 \
        BUILD="$w/pdp6" ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem \
        SIMH_CPU_KWORDS=64 BOOT_CORE_WORDS=0200000 COMPILER=kcc \
        TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 image
    python3 -B native-v1964.py "$w/ka10" "$w/pdp6" "$PDP10_PREFIX" "$w/native"
    python3 -B trap-v1964.py "$DAIMOS_REPO" "$PDP10_PREFIX" "$w/trap"

The native boot harness copies the tape media, reads the installed trap
vectors and APR state, and compares Stage1 and uncompressed INIT, LOGIN,
DSH DXRs across both machine builds. The physical INIT transcript can
also be rechecked with --replay LOG. The trap probe executes the actual
KA10 handler in both user and executive mode with a bounded terminal
cleanup stub, not a complete process-fault lifecycle test.

The initial KA10 build is 64K ONESEG with MAOFF disabled. RH10 devices
must be disabled because their first automatically assigned address 270
conflicts with the Type 270 controller. The unchanged DAIMOS disk driver
has passed the source-linked v1958 queue, read and silent recovery cases:

    python3 -B ../dsk270-octoflop-v1950/run-v1950.py \
        "$PDP10_PREFIX/bin/pdp10-ka" "$PDP10_PREFIX" "$w/octoflop" --ka10
    export DAIMOS_TEST_MACHINE=ka10
    for mode in queue read silent; do
        python3 -B ../dsk270-runtime-v1958/queue-v1958.py \
            "$DAIMOS_REPO" "$DAIMOS_REPO/system/kernel/drivers/dsk_io.s" \
            "$w/$mode" "$mode"
    done

Do not infer a complete KA10 release gate from these component tests.
Interactive CTY login, normal RUN/EXEC/BRK/WAIT/EXIT, protection-fault
cleanup, disk root, and pressure qualification remain separate.
