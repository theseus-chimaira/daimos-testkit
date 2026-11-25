# v1941 physical PURE pressure/FULL replay checkpoint

No production kernel or compiler source change. Original source-built
GCC 48K v1940 guest reused, matching the recorded KCORE/PURE hashes.
The real unmodified six-child workload emitted aaaaa!r: five checked
sleeping children (one plain, four compressed) and sixth RUN refusal.
The operator interrupted SIMH after the failure marker. The
automatically captured B-labelled dump is NOT a successful B
checkpoint: the original B marker is absent and the controller
correctly exits 1. The actual guest did not complete its intended
WAIT/EXIT workload or reach the authenticated FULL callback.

Evidence: $TMPDIR/pure-k07-full-v1941.iOwGkG/physical.clean.
Original build: $TMPDIR/pure-brk-pressure-v1614.Fx9gcX/build.

    python3 tests/validation/pure-k07-full-v1941/audit-refusal-v1941.py \
        "$TMPDIR/pure-brk-pressure-v1614.Fx9gcX/build" \
        "$TMPDIR/pure-k07-full-v1941.iOwGkG"

The executed diagnostic audit confirms MM17/capacity32, one managed
arena, slot0, high slot7 (exclusive), zero reservation head and no
slot7 VM/u-area allocation. Slots3..6 retain exact unpinned 07000
PACKED extents. Slot2 has pinned PACKED 120000..130000, expanded to
010000 words, consistent with its in-progress plain restoration.
The parent has already begun failure exit and its VM is gone; the
top 130000..140000 APR is free at this snapshot. This is NOT a
pre-sixth-RUN allocation snapshot and cannot prove exact NOMEM.
Both actual installed service/reclaim JRSTs independently derive
PURE base 033136, candidate FULL entry 040756. The latter was not
executed under the new breakpoint controller yet. No FULL acceptance.

The new read-only controller resolves the current linked offsets and
installed service jumps, checks original FULL entry opcode before
breaking, and records B/A/FULL/Z MM snapshots. It requires all checked
RUNs plus the next refusal, exact nonoverlapping same-owner source
and target pins, matching original PACKED identity, stable u-area
owner, empty reservation head, all checked child WAITs and normal
HALT. The current 48K descriptor capacity is 32. Earlier diagnostic
read the maximum 136 slots; only the active 17 are audited; the
updated runner limits the dump to the actual 48K profile's table.
Private output files and tapes are used in the new runner.
Monitor pipe smoke passes. Seven synthetic unsafe geometry cases
reject and the actual incomplete trace is rejected by the acceptance
verifier. Complete physical replay remains unverified.

## Adapted five-child test fixture

The observed sixth refusal invalidates the historical fixed six-child
success geometry for this image, not the requirement for real pressure.
The five-child source differs only in child count and associated
comments; the required next RUN refusal remains, as do actual private
data sentinel and PID/EXITED/status WAIT checks. This does not alter
kernel capacity or weaken the physical FULL owner proof.

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1941_ORIGINAL_BUILD=$TMPDIR/pure-brk-pressure-v1614.Fx9gcX/build
    sh tests/validation/pure-k07-full-v1941/prepare-five-v1941.sh

The builder passed, preserving byte-identical KCORE, KINIT and PURE
images, recompiling the five-child guest and rebuilding genuine
three-member TSFS (54 files, 315 extents). The plain and compressed
DXR2 headers are valid and the source-derived fixture is ready:

    export V1941_BUILD=$TMPDIR/pure-k07-five-v1941.3uWwvd/build
    make test-pure-k07-full-v1941

The new five-child full replay has NOT yet run. The runner can also
challenge the old six-child case using V1941_CHILDREN=6 and its
original build. No background simulator left running. Next gate:
execute the five-child pressure workload to normal HALT, verify
actual FULL callback ownership and then exercise the real PI6
reservation/retirement and source-loss acceptance. K07 OPEN.
