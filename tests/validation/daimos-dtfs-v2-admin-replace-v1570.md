# v1570: real Type-551 DTVOL2 poisoned-reel administrative replacement

Date: 2026-11-14. P0-B replacement subset accepted; writable V2
remains disabled in production.

## Production change and exact safety scope

The old private DTFS `VERIFY_REPLACE` operation 026 only admitted a
different independently validated DTVOL1 RBN0. The production
`dtfs_verify_replacement_v1531` now discriminates V1 and V2 by the
physical header *and* the original mounted FORMAT_V2 bit. A poisoned
V1 mount still requires a different valid V1. A poisoned V2 mount
requires a different, fully sealed **DTVOL2/CLEAN** volume. Same
72-bit identity, DIRTY, invalid seal, zero IDs, nonzero padding,
incomplete physical read, invalid native directory and cross-format
replacement all refuse. The separate v1531 owner barrier, MM scratch,
process-swap/PIPE/CWD/FILE scans and exact final retirement did not
change. This is an explicitly destructive privileged slot discard,
never data repair or automatic recovery. No V2 write access enabled.

## Real PDP-6/native source-linked oracle

`daimos-dtfs-v2-replace-native-v1570.sh` uses four genuinely
independently formatted full physical DTVOL1/V2 images (two of each),
and the source-extracted actual `dtfs_verify_replacement_v1531`,
`dtfs_intent_validate_v1550`, v1522 parser and v1558 workspace
clear/poison instructions. Thirty PDP-6 cases PASS for positive V2
and V1 replacement, same original, cross-format refusal, actual
DIRTY and malformed V2 records, independent 72-bit identity,
nonzero padding, partial/false-successful Type-551 reads, reserved
native directory markers and missing original IDs.

Eight unsafe mutations are rejected in real PDP-6 execution:
V2 seal bypass; treating DIRTY as CLEAN; ignoring old V2 format;
allowing V2-to-V1 downgrade; admitting identical identity;
missing directory verification; missing directory workspace clear;
and skipping the raw physical RBN0 transfer. A candidate mutation
that omitted RBN0 prefill was discarded from this suite because the
preceding complete directory read prevented the mutation from being
observable; no false mutation success is reported.

The preceding v1558 20-case/six-mutant source-linked regression was
rerun with the new parser linked and PASSed. The historical complete
v1531 privileged DTVOL1 physical guest also PASSed unchanged.

## Real physical 256K KCC PDP-6 guest

`daimos-dtfs-v2-admin-physical-v1570.sh` uses the v1568
source-matched **disposable** RW image builder, exact DTC3/mount2,
and the v1529 diagnostic Type-551 `PARTIALWRITE=0145:1`. It first
asserts unmodified production v1555 RW mount refusal. The test-only
permission is published only after the real DTFS provider saves the
full 72-bit ID; a test-only MRES one-shot flag ensures the second
fresh mount stays genuinely read-only. Production DTFS MRES and VFS
are not modified except for the v1570 replacement verifier itself.

The guest physically executes the genuine v1551-v1554 DIRTY intent
and two-word RBN0145 seed, then a real interrupted DATA write. Both
simulator DETACH snapshots are independently verified: original
RBN0 remains valid DIRTY, exactly one requested 36-bit DATA word
changes, and the other requested word stays old. The original tape
cannot be removed by ordinary CLOSE/UNMOUNT or privileged replacement
while FD or cwd owners remain. An exact privileged DROP_FD followed
by CWD release clears those owners, but reinsertion of the original
same-ID DIRTY tape still cannot retire the poisoned mount.

A completely independently formatted different-ID DTVOL2/CLEAN
reel is attached. The live production private replacement verifier
physically checks the native directory and full CLEAN RBN0, then
the unchanged VFS post-I/O owner barrier permits checked retirement.
A fresh RO mount succeeds; the old file is absent, a new CREATE is
refused as RO, and normal unmount completes. The guest reports
`DTFSV2ADM V1570 PASS`.

The original and replacement were attached by **distinct SIMH
backing filenames**. Independent whole-reel fingerprints were
checked against their respective original files, not one another:

```
Original physically damaged DIRTY:
e06664a3bac2dc0a6c730648871eeb0692b22cdde19aec82b65c336b1c59aa94
Different valid CLEAN replacement:
2a32fdea8e863f3153fd5ce2d83ae8c3887639d6f81755339c90b4891d1ffbe4
```

A first verifier run accidentally compared the replacement to the
original DTC3 filename; that host-side path error was corrected
and the entire physical sequence rerun. Neither kernel nor on-media
payload was changed to conceal the error.

The exact damaged original is subsequently cold-booted by an entirely
unchanged production KCORE/MRES: RW/RO both refuse, mount remains
unpublished, and full media SHA-256 is unchanged. A second cold boot
uses the exact independently mounted CLEAN replacement and unchanged
production KCORE/MRES: normal RO mount, owner checks, unmount,
remount and unchanged tape SHA-256 are required.

## Reproduction

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh "$HOME/git/daimos-testkit/tests/validation/daimos-dtfs-v2-replace-native-v1570.sh"
DAIMOS_V1568_BASE_BUILD="$TMPDIR/daimos-v1570-image-r1" \
    sh "$HOME/git/daimos-testkit/tests/validation/daimos-dtfs-v2-admin-physical-v1570.sh"
```

The optional base image can be omitted and rebuilt from current
production source. The physical test uses the established separate
diagnostic `$PDP10_PREFIX/bin/pdp6-v1529r5` simulator.

## Unresolved hardware problem

Type-551/136 offers no persistent reel-generation identity or
mechanical prevent-eject interlock. A physical reel can be exchanged
after RBN0 verification but before a following WRITE. The software
cannot atomically prevent that change with additional RBN0 reads.
This test accepts checked **replacement only after the old mount is
already poisoned and its owners are explicitly dropped**. It does
not permit continuous RW on externally removable media and does
not justify removing the v1555 production READ-ONLY veto.

No fixed KCORE TEXT/DATA/BSS, boot ABI or mount-slab RAM growth;
only a small additional optional DTFS MRES code path. Lowcore end
remains `024364` octal. P0-A CLOSED, P0-B OPEN, P1-C/D/E unchanged;
VERSION 0.5, strict 32K optimization HOLD.
