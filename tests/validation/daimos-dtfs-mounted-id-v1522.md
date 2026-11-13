# v1527 correction: real BCACHE workspace identity (2026-11-13)

The original v1522 test fixture declared local
`bcache_state`/`bcache_workspace_tag` words that
were **not the actual data labels used by the
source-linked BCACHE assembly unit**. Consequently,
v1522 had accurately tested the media-suspect and
volume-ID branches but had **not** tested real
workspace-slot cache-tag correctness. The v1527
fixture now exposes the existing production
BCACHE data labels within the test image and
removes the duplicate fixture variables, allowing
the real source to use its actual state.

The extended native case seeds a real L1
`fs_block_workspace` tag with a clean simulated
TSFS record, then executes the **production**
raw RBN0 different-ID revalidation. It requires
that the workspace tag be invalidated and that
the old key return an actual BCACHE miss. The
new eighth source mutation,
`stale-workspace-tag-v1527`, replaces the
single `bcache_workspace_invalidate` call with
a harmless instruction. The executed native
fixture rejects that mutation, as well as
all seven original v1522 unsafe mutations.
This matches the independent 256K real guest
result from physical DTC3/DTC4 media exchange.

The original scope and history below are retained
as the v1522 checkpoint; the v1527 evidence
supersedes its older cache-tag coverage claim.

# DAIMOS native DTFS mounted-identity validation v1522

Date: 2026-11-12. Feature-correctness regression for production
`system/kernel/fs/dtfs_runtime.s`, following native identity
mount admission v1520 and read-error BCACHE invalidation v1518.

## Scope and fixtures

`daimos-dtfs-mounted-id-v1522.sh` extracts the actual PDP-6
assembly for the raw DTC read/write wrappers, mounted-unit failure
marker, common identity parser, mounted-media revalidation, native
directory loader, DTFS sync/space and the real shared BCACHE. Only
the DTC physical I/O return and the boot-published four-slot MM
mount slab are controlled by the test fixture. This is a
source-linked *native* PDP-6 run, not a booted multi-process guest.

The source-linked oracle checks:

1. Initial legacy and stamped mounts work, including healthy
   FSINFO and SYNC.
2. A failing physical read on DTC3 marks only the two live DTFS
   mounts on that unit. Unrelated DTC0 and a D6FS mount carrying
   the same low media selector are not marked.
3. An absent medium cannot supply cached directory, FSINFO or
   SYNC success.
4. A fresh physical read of reserved RBN0, with valid DTVOL1
   structure and both exactly matching stored 36-bit ID halves,
   permits same-volume return and a fresh directory fetch.
5. Different valid replacement stamps changing *only* the high
   or *only* the low ID half are both rejected; the mount's
   failed-media flag and old ownership remain intact.
6. Returning the original exact identity permits retry.
7. A physically failed write sets sticky WRITE_UNCERTAIN for
   all live DTFS mounts sharing the unit. Even when media returns
   with the original identity, old directory access, SYNC and
   FSINFO fail closed.
8. A failure on unrelated DTC7 does not poison other mount slots.
9. An unstamped legacy volume can initially be used, but cannot
   prove safe same-volume return following a physical read fault.

Seven executed unsafe source mutations are rejected, one each
removing the read marker, removing the write marker, bypassing
the high half comparison, bypassing the low half comparison,
accepting a zero-ID legacy return, ignoring WRITE_UNCERTAIN,
and losing the mount-slot register across a raw DTC transfer.
The low-half mutation is exercised independently, not by
repeating a test that modifies only the high half.

## Additional regression checks

All PASS after fixture-only adaptation to the new installed
error-state ABI: v1490 BCACHE read/write/refused-free with two
negative controls, v1518 I/O-error invalidation with four
negative controls, v1519 raw native directory admission with
six negatives, v1520 header/stamp mount with five negatives,
native DTFS create/unlink/rename/resize/chain/dirfields,
v1516 TSFS physical root-member classification with four
negatives, and BCACHE allocation and multisource.

The old v1490/v1518 isolated fixtures have no live mounted
volume ID state; their narrowly scoped tests therefore provide
empty mount-slab stubs or an identity-neutral loader boundary.
The new v1522 oracle alone establishes post-error mounted-ID
comparison. No source of truth was added to production for tests.

The clean 256K KCC tape-root KINIT/KCORE plus DTFS/TSFS MRES
package assembled and linked. The separate strict single-root
memory-placement check still fails; it was not reclassified as
boot acceptance. Controlled identical-companion, same-KCORE-map
folded MRES relink changes DXR text from octal 003620 to
003746: **+86 decimal optional MRES words**, unchanged
two-word package BSS, no added fixed KCORE or per-mount data
words. See DAIMOS
`design/kcore-dtfs-mounted-identity-v1522.md`.

## Still not accepted

No full physical guest with open FILE/vnode and concurrent
processes, forced physical tape exchange, dirty write recovery
or VFS mount retirement is claimed. Silent exchange without
observed I/O is not detected. The Type-551 offline/removal
event remains unresolved, and there is no v1515 fatal HALT
caller for root/BACKSTORE loss. WRITE_UNCERTAIN is intentionally
sticky until a future explicit, failure-atomic recovery policy.
