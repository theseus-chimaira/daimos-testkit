# v1943: physical PURE reservation / retirement race

This test is independent of the v1942 48K pressure geometry. It uses
a smaller source-derived guest with a writable, stamped native DTVOL2
secondary mount on DTC3 and a three-member TSFS root on DTC0..2.
All actual RUN, FILE, mount, MM, scheduler and owner checks are original.

Two disposable scheduling windows widen actual kernel race boundaries:
- after the actual executable reservation and namespace epoch check,
  before STAT, a DTFS load sleeps 010000 real ticks;
- after actual V2 admission-barrier acquisition, before SYNC, ordinary
  unmount sleeps 04000 real ticks.

The root-backed independent actor receives a PIPE token and sleeps
02000 ticks before challenging UNMOUNT during the loader window.
Its refusal must occur with a live parent-stack reservation, no
permanent secondary backing record and no held physical provider lease.
The parent then completes the compressed RUN and both exact WAITs.
The second ordering starts a real unmount, observes FSINFO refusal
on the still-published quiescing mount, attempts RUN (must refuse),
and verifies no changed MM/backing ownership before retirement.
Same-medium remount, successful RUN, WAIT and final unmount follow.

The source builder compares the complete original assembly files
before insertion and compares copied instrumented assembly after
the normal image build. Production source is not edited. No
production RAM measurement is implied by the disposable additions.
The first-write arm is not required of an otherwise healthy CLEAN
RW remount. Monitor commands only inspect original physical state.

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1943_BASE=$TMPDIR/pure-brk-pressure-v1614.Fx9gcX/build
    sh tests/validation/pure-k07-race-v1943/prepare-kcore-v1943.sh

The builder passed with source-matched copied assembly, physical
DTVOL2/CLEAN verification and genuine TSFS verification (54 files,
320 extents). Prepared build:
$TMPDIR/pure-k07-race-v1943.mAORcb/build.

    export V1943_BUILD=$TMPDIR/pure-k07-race-v1943.mAORcb/build
    make test-pure-k07-race-v1943

The physical runner resolves the actual process, mount, media and
backing-table pointers from the current physical memory and map,
checks active MM extents only, and preserves private media copies.
It requires both orderings, exact guest markers and one normal HALT.
The initial build and script syntax checks passed; this README
does not claim successful execution of the complete physical gate.

## First physical diagnostic and revised fixture

The first physical run booted, installed PURE and DTFS, and was
manually interrupted after approximately seven minutes without the
IE guest marker. The controller correctly rejected the monitor-only
E label; no race acceptance. At stop PC032077 (CONI 214,4), actual
current slot1, high slot2, provider lease 000002,,000000, reservation
head zero, namespace epoch 021, MM8/capacity32 and physical clock
061145 octal (25189 decimal). The selected TSFS root is unchanged.
The original Type-551 search loop contains the observed CONI.
This sample alone does not prove a deadlock or identify the exact
outstanding transfer. The lease is still held by PID1 during setup.

The original sealed DTVOL2 volume identity is unchanged. The
interrupted private DTC3 tape has DIRTY word 552255225522 and
changed physical records 0 and 100..107 (decimal). The original
private test source had not emitted its seed completion marker.
This establishes actual physical writes, not a verified complete
file, CLEAN publication or remount. Do not reuse the partially
written tape for the next acceptance run.

Evidence:
$TMPDIR/pure-k07-race-physical-v1943.5eSZOf/physical.clean
SHA256 0e8a6677a56c70c9adfd3ca285ec58bceb20ee6a84a9c7044e717a680bcb89a2.

Revised generator adds lowercase setup markers i (start), j (mount),
k (open), c (each completed copy write), d (both FDs closed),
s (chmod complete), u (unmount complete), I (remount verified).
No syscall acceptance checks are removed. The monitor now dumps
active physical tables even on an unexpected stop, then rejects the
missing guest marker. Revised build passed source comparison,
DTVOL2/CLEAN and TSFS verification (54 files, 320 extents).

    export V1943_BUILD=$TMPDIR/pure-k07-race-v1943.ZEw7l7/build
    make test-pure-k07-race-v1943

The revised fixture has not yet been executed. Run to its bounded
completion; monitor progress using the new seed markers. Both race
orderings, runtime verifier and normal HALT remain pending. The
first run was deliberately stopped, not a measured 1150-second
timeout. No simulator remains running. No production source changes.
