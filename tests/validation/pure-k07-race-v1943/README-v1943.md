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
