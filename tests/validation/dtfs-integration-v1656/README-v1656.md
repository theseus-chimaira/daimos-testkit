# v1656: restore current-source native DTFS V1 integration acceptance

Date: 2026-11-17. The historic original source-linked
PDP-6 v1518 and v1522 integration tests now PASS
on current v1655/DAIMOS production source, again
rejecting all twelve original unsafe source mutations.
The current v1655 independent 82-case/39-mutant matrix
passes alongside them. No production source was changed.

## Why old scripts stopped working

The original v1518 bridge test encoded the former raw
write veneer and ran before the production v1561
physical-unit first-write mount gate. After v1561, the
write veneer enters the real mount gate BEFORE cache
invalidation. The original fixture left the MM/VFS
mount tables zero and a mutation anchored to a removed
source comment. The actual kernel was not demonstrated
wrong by this obsolete fixture.

The fixed v1518 test still compiles the exact original
raw DTC read/write veneer, original native DTFS loader,
and complete real BCACHE. It NOW ALSO links the
unaltered original v1561 mount gate. The native test
fixture publishes a genuine V1 mount2 on physical
DTC3 and VFS limit2, so that original policy permits
the physical write. Its V2-only first-write service
is an explicit fail-closed test function that must
never be entered by V1. The write BCACHE mutation
now changes the actual cache-invalidate call before
the original hardware jump, rather than matching a
removed comment. The unchanged fixture still tests
real data/tag invalidation after read/write errors,
source error preservation, recovery and successful
write. All four unsafe mutations execute and fail.

The original v1522 standalone extractor used a
now-removed v1531 section marker after dtfs_space
and an outdated saved mount-slot unpin sequence.
The v1656 update extracts EXACTLY the actual
dtfs_space function up to the current v1575 private
discard-drain header, preserving original FSINFO
behavior. The original full raw DTC wrappers,
V1 parser, V1/V2 identity revalidation, directory
loader and complete real BCACHE are still linked.
It now also links unaltered v1561 physical-unit
intent gate with real published four-slot VFS
roots; fixture media are V1 on DTC3, so no V2
first-write service may be entered.

Its eight independently compiled/executed unsafe
mutations still test read-fault marking, write-
uncertain marking, rejecting changed high and low
36-bit IDs separately, refusing unsafe legacy
recovery, refusing WRITE_UNCERTAIN re-entry,
retaining exact original mount slot across
blocking physical I/O, and invalidating the
original BCACHE workspace tag before direct RBN0.

## Reproduction

With original DAIMOS and daimos-testkit checkouts:

    export TMPDIR=$HOME/tmp
    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross
    sh tests/validation/dtfs-integration-v1656/run-v1656.sh

The versioned runner rejects fixture extraction,
assembler/link failure or a mutation dying outside
its native oracle. It combines both original
integration tests with current v1655:

- Two source-linked integrated V1 raw-I/O tests, 12
  rejected unsafe mutations.
- 82 separately enumerated V1/V2 physical identity,
  DIRTY, mounted-intent and MM owner cases; 39
  rejected unsafe mutations.

Total: 51 executed and rejected bad-source mutations.
Not a full physical 48K Type-551 parallel process
guest. The real v1643-v1647 physical media/owner
tests remain independent. The accepted v1575 writable
volume operator trust contract still applies; no
silent reel exchange interlock exists.

The original stale v1518 and v1522 integration
gap of the v1655 TODO is closed by this v1656
source-linked native evidence. Overall PDP-6
KCORE feature freeze still needs full peak RAM,
permanently uncertain owner policy, optional
compression decision and final system test matrix.
Strict 32K boot/size acceptance remains deferred.
