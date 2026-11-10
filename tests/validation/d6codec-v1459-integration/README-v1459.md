# v1459 real-build block decoder integration acceptance

This test directory contains **actual full-image cold-boot tests**,
not only a standalone codec unit test. DAIMOS v1459 selects the
v1458 53-word fixed core in both Stage-1 and KCORE, and the
58-word VFS adapter in KCORE. The older block v1452 wire format
is unchanged; the host encoder remains `d6block-v1452`.

`linked-core-v1459.py` verifies the entire 53-word low-core
image in the linked KCORE DXR against all five Stage-1 assembled
raw read-in images. This includes the inline LDB pointer word.

`boot-v1459.py` runs the real image in SIMH, using independent
copies of all attached writable media. It waits for login, logs
in as ROOT, starts DSH and executes an ECHO command. Use unique
`--dcs-port` and `--ge-port` values for concurrent simulations.

Example, from the daimos-testkit root:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    python3 -B tests/validation/d6codec-v1459-integration/boot-v1459.py \
        --boot "$TMPDIR/daimos-v1459-build" \
        --prefix "$HOME/cross" \
        --output "$TMPDIR/d6codec-v1459-integration/dsk-full"

The boot directory must already contain a completed `make image`
build, with `boot.ini` and all referenced media files. The
source worktree and its original media are never modified by
the test. A failed or timed-out boot is **not** a pass.

## Results from the first integration run

The 256K full-profile DSK, DRM and PTR Stage-1 boots reached
ROOT login, DSH startup and successful ECHO. The 48K lowmem
build reached `INIT V1` but did not reach login within 180s;
the unmodified v1452 control exhibited the same result.
The strict 32K lowmem build failed its pre-existing KINIT
stack-safe size gate. A full-profile DSK boot with TSFS root
reported `INIT: RUN FAILED`, identically to a separately built
v1452 control. Neither 48K nor TSFS-root behavior is accepted
as a successful runtime boot. The DTC/MTC source assemblies
and byte-exact core image comparisons passed, but DTC (180s)
and MTC (240s) cold boots timed out before the boot banner;
they are not accepted.

Source-level integration is in the DAIMOS branch
`d6codec-v1459-integrate-20261110`; baseline is
`d6codec-block-cutover-v1452-20261110`. Build outputs are
versioned and isolated under `$TMPDIR`.
