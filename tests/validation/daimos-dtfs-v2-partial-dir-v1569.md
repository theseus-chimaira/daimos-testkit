# v1569: real Type-551 V2 directory partial write and second cold boot

Date: 2026-11-14. Actual PDP-6 guest DIR partial, sticky owner and
production cold boot **PASS**. Production DTVOL2 stays READ-ONLY.

## Real software and physical boundaries

The full 256K PDP-6 KCC guest boots the actual TSFS root and
independent DTC3 DTVOL2/CLEAN Type-551 reel. The source-matched
production VFS/MRES image is copied into a disposable build. Only
that copy contains an exact DTC3/public mount2 late RW policy
test hook and a matching write-veto exception *after* the true
published 72-bit volume ID and root owner. The initial production
RW mount is refused, proving the actual v1555 veto still operates.
The unmodified v1551-v1554 physical first-write and MM-pinned
WRITE_INTENT guard is still the sole path to DATA/DIR writes.

For the directory-specific run, two **test-only** KCORE VFS CREATE
instruction breakpoints are linked and verified in the actual
KCORE map. They stop SIMH immediately before and after the second
CREATE service; the production DTFS CREATE and hardware write,
including error handling, execute unchanged in between.

Real PID1 first creates `/MOUNT/DT0/FIRST`. At the pre-CREATE
breakpoint, SIMH DETACH persists the first successful physical
write. A full-tape byte comparator proves only RBN0 (valid salted
WRITE_INTENT) and the native directory RBN0144 changed. The original
72-bit ID is unchanged, and neither DATA nor other blocks changed.

The diagnostic simulator next arms `PARTIALWRITE=0144:1` and
resumes the actual second CREATE (`/MOUNT/DT0/SECOND`). The real
Type-551 write is interrupted after the first **changed** 36-bit
directory word. The genuine controller failure propagates to the
running DTFS and VFS; the second CREATE refuses success. At the
post-CREATE breakpoint, SIMH DETACH flushes the actual physical
tape. Independent full-tape verification proves **exactly one**
directory word changed and no other word changed, including the
complete valid DIRTY RBN0. That physical delta contains six image
bytes because of the simulator's stored 18-bit halfword layout.

The guest then proves FSINFO, CHDIR and UNMOUNT refuse the poisoned
DTFS mount, while the independently mounted TSFS root remains
accessible. PID1 reaches `DTFSDIR V1568 PASS`.

The exact physically damaged reel, not a regenerated model, is
reattached to a fresh **entirely production** KCORE/DTFS MRES image.
The new cold-boot guest observes RW_REFUSED, RO_REFUSED, UNPUBLISHED
and PASS. Both whole-reel SHA-256 values match:

```
a85673f46bc72ce3707186c159c794253e091878a5ad5fe398b4e2dae864f8ae
```

The first physical CREATE modified 17 image bytes, the interrupted
second CREATE modified six bytes. Original CLEAN and seeded DIRTY
whole-tape digests are checked by the independent host-side
`daimos-dtfs-v2-partial-dir-verify-v1568.py` comparator; no step
rewrites or repairs the damaged reel.

## Reproduce

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
V1568_MODE=dir \
    DAIMOS_V1568_BASE_BUILD="$TMPDIR/daimos-v1566-image-r1" \
    sh "$HOME/git/daimos-testkit/tests/validation/daimos-dtfs-v2-partial-data-v1568.sh"
```

The base build is optional: without it, the script compiles an
independent production full guest first. The diagnostic
`pdp6-v1529r5` simulator is test-only and carries the established
Type-551 changed-word fault facility. Data-mode uses the same
runner with `V1568_MODE=data` (default), retaining v1568 tests.
After the directory extension, the complete v1568 physical DATA
and second unchanged-production-cold-boot regression was rerun and
PASSed, including its independent full-tape SHA-256 comparison.

## P0-B boundary

Together, v1567 actual partial CLEAN, v1568 actual partial DATA and
this directory failure cover physically interrupted RBN0, DATA and
DIR transfers with cold-boot refusal. They **do not** prove safe
full production writable DTVOL2. The Type-551 lacks a persistent
reel-generation identifier, prevent-eject or atomic selected-media
interlock; an external reel can be changed between a checked ID and
the next hardware transfer. Same/replacement media reinsertion and
operator-controlled exchange across RW remain open.

No production kernel, physical driver, MRES, ABI or fixed RAM changes.
P0-B remains OPEN, P0-A CLOSED, P1-C/D/E unchanged, VERSION 0.5,
strict 32K optimization HOLD.
