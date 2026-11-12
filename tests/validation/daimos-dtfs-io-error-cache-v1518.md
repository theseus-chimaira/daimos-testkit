# KCORE v1518: observed DTFS I/O failure invalidates shared cached identity

Date: 2026-11-12. Source-linked native PDP-6 acceptance of fail-closed
DTFS cache behavior after a negative physical read/write. This is a
targeted correctness fix, **not** automatic DECtape removal detection,
physical tape reattachment, or authorization to use replacement media.

## Actual bug and fix

The optional `dtfs_runtime.s` provider uses both a single shared
`dtfs_cache_mount` directory identity and the fixed-KCORE two-entry
clean `BCACHE` keyed by physical DTC UNIT,,BLOCK. `dtfs_load()` skips
loading a directory while its mount ID matches `dtfs_cache_mount`;
ordinary `dtfs_dtc_read()` may also return a previously cached clean
block without performing a hardware operation.

Before v1518, a physically failed read returned negative but retained
the shared directory identity and potentially valid clean tags from
earlier reads. A later operation on the same mount could incorrectly
accept its former in-memory directory without trying the device again.
A physically failed write invalidated the clean block tags before
writing but left the directory identity marked current even though
the partial or failed write might not have committed directory data.

The corrected production wrappers now invalidate both clean BCACHE
tags and clear `dtfs_cache_mount` on a *negative physical read*,
preserving the original negative return. The write veneer still
invalidates clean tags **before** hardware I/O, retaining the exact
unit/block/buffer ABI. It now observes the physical write return and
clears the directory identity on error; a successful write retains
the same in-memory mount identity. No mount slot is retired, no
backing is forcibly freed, and no permanent process or media state
is introduced. Shared clean tags are invalidated without invoking
MM reclaim; a failed `mm_free` cannot preserve a stale identity.

## Executed PDP-6 source-linked regression

`daimos-dtfs-io-error-cache-v1518.{s,sh}` links the actual
production DTFS physical read/write veneers and native `dtfs_load`
directory loader, together with the **complete production BCACHE**
assembler implementation. Only the normal boot-patched physical
DTC jump slots are redirected to deterministic raw-device callbacks;
the MM slab is preseeded to avoid testing allocation here.

It verifies:

- A successful directory read for secondary DTFS mount ID 2 on
  physical DTC3 populates both the directory identity and a genuine
  clean block-cache entry.
- A different uncached physical read fails when the same device is
  temporarily unavailable. The error remains -1, both clean tags
  become invalid and the previously cached mount directory identity
  becomes zero.
- The next directory load from the same mount while unavailable
  actually retries physical DTC I/O and fails, rather than succeeding
  with a stale directory or cached block.
- On return of the *same* device, the directory is fetched anew
  and successfully cached. This is not a replacement-identity test.
- A failed physical write likewise clears all clean tags and
  the directory identity, and a subsequent directory access fails
  while the device is unavailable.
- A successful physical write invalidates clean tags but retains
  the valid directory identity. Raw physical unit/block/buffer ABI
  remains intact.

Four **executed** negative source mutants are rejected: leaving the
directory current on a failed read, skipping read-side BCACHE
invalidation, leaving it current on a failed write, and bypassing
the write-cache-invalidation gate. Each mutant must fail the actual
PDP-6 test oracle; source-string comparisons alone are not accepted.

Existing native BCACHE multisource, BCACHE MM-free-refusal/writer
ABI (v1490), DTFS chain walk, DTFS create/unlink/rename/directory
field and TSFS cross-member read suites also PASS. The older v1490
standalone fixture needed an exported, unused `dtfs_cache_mount`
symbol and an updated negative mutation anchor for the new write
call site; no production shim was added.

## Scope and target size

An isolated full 256K KCC tape-root KINIT/DTFS-TSFS MRES build
and link PASSES with the new source. A controlled old/new optional
MRES relink using identical other objects, the current KCORE map
and separately generated p10fold plans gives **+6 optional MRES
instruction words** and **+0 permanent data words**. Fixed KCORE
is unchanged. The independent 32K fixed-KCORE strict size gate
already exceeded its memory budget in v1516; v1518 does not
claim its acceptance.

## Unresolved removal and identity boundaries

The physical DTC driver still does not expose a confirmed media-loss
event. An offline device whose entire requested dataset remains
cached may not generate a physical I/O error, so this bug fix does
**not** guarantee immediate failure on a silent hot-unplug. Nor can
it distinguish the *same* reinserted tape from a *different* tape
after an error. A successful physical read is not proof of volume
identity, even if the directory format looks valid. Reusing old
open vnodes or writing to replacement media without a checked
remount/revalidation protocol remains unsafe and is not accepted.

True root TSFS disappearance still requires authoritative
physical loss detection and v1515 fatal dispatch. Non-root DTFS
device replacement, volume identity, dirty data and open-file
ownership remain P1 feature gates; do not invent retry thresholds,
quarantine statuses, or implicit successful remounts.
