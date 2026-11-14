# v1568: actual physical DTVOL2 DATA partial write and cold boot

Date: 2026-11-14. **PASS.** Production DTVOL2 remains read-only.

## Exact scope

The full 256K PDP-6 KCC guest boots its real TSFS root and attaches
an independent native Type-551 DTC3 DTVOL2/CLEAN tape. The baseline
production source is checked against the copied test image's VFS and
assembled DTFS MRES. The unmodified production v1555 writable mount
refusal is tested first.

For this isolated test image ONLY, after the genuine provider has
published the V2 physical unit, public mount slot and both halves of
the 72-bit volume ID, an exact DTC3/mount2 hook clears that slot's
read-only policy. A second exact-unit/slot hook permits its physical
write through the otherwise unchanged v1551-v1554 first-write
intent, MM scratch, physical verification and central DATA/DIR write
path. Neither hook exists in any production KCORE/MRES source or
installed production binary. All other mounts remain read-only.

The existing v1529 real PID1 first creates a two-word file and
physically writes two seeded data words. SIMH DETACH persists the
entire tape. The independent verifier confirms CLEAN RBN0 became
valid salted DIRTY, native directory block 0144 and file DATA block
0145 both changed, the exact seeded data words are present and no
other physical blocks changed. The first write was therefore gated
by genuine physical WRITE_INTENT before DATA/DIR mutation.

The host reattaches the same physical tape and arms the existing
diagnostic Type-551 `PARTIALWRITE=0145:1`. The second real guest
write fails after exactly one changed 36-bit DATA word. A second
DETACH persists the result. The independent verifier confirms only
RBN0145 changed, exactly one requested new word reached media, the
other retained its old value, and the entire valid DIRTY RBN0 was
unchanged. Guest FILE/FSINFO/unmount tests confirm sticky poisoned
mount ownership; TSFS root remains alive. Final whole-tape SHA-256
matches the post-failure snapshot.

The **exact physical damaged tape**, not a regenerated model, is
then cold-booted under the entirely unmodified production KCORE and
DTFS MRES. Both RW and RO mount attempts refuse, no VFS mount is
published, and complete tape SHA-256 is unchanged. The test does
not claim recovery of damaged old file data.

## Reproduction

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
export DAIMOS_V1568_BASE_BUILD="$TMPDIR/daimos-v1566-image-r1"
sh "$HOME/git/daimos-testkit/tests/validation/daimos-dtfs-v2-partial-data-v1568.sh"
```

If the optional prebuilt full production image is not supplied,
the test builds one. The Type-551 diagnostic simulator is the
previously accepted `$PDP10_PREFIX/bin/pdp6-v1529r5`.

## Remaining limits

This is actual physical DATA failure with an authentic first-write
DIRTY barrier, not proof of full production writable DTVOL2.
Actual partial V2 directory-metadata transactions, same/replacement
reel reinsertion and operator-controlled media exchange across a
write remain unaccepted. The Type-551 has no hardware reel-generation
interlock; an extra RBN0 reread cannot make media exchange atomic.
Do not remove the production v1555 read-only veto on this evidence.

**P0-A closed, P0-B OPEN, P1-C/D/E unchanged.** Zero production
TEXT/DATA/BSS/ABI change; strict 32K optimization HOLD.
