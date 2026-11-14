# v1561: production DTFS physical-unit to retained intent/MM write gate

Date: 2026-11-14. KCORE P0-B production integration stage,
**not** writable V2 or full Type-551 durability acceptance.

## Production source path

The existing common `dtfs_dtc_write` entry receives only the
Type-551 physical unit, block and pending data buffer. v1557
provides unique mounted V2 physical-unit ownership, v1560
provides the exact MM-backed per-mount auxiliary pointer, and
v1551-v1554 already implement the physically checked DIRTY
marker and pinned-MM arm/revalidation, but were previously
separately assembled rather than linked into live DTFS.

v1561 now links all of these native assembly leaves into the
production optional DTFS MRES and calls
`dtfs_intent_mount_gate_v1561` from the actual central data/
directory write veneer, **after** the existing unconditional
v1555 READ-ONLY V2 refusal and **before** the physical DATA/DIR
write. Because the earlier veto is still mandatory, live V2
does NOT yet arm RBN0 or execute DATA/DIR writes.

The new bridge scans published VFS DTFS root and MM media slots
by the physical DTC unit. Ordinary legacy V1 (including previous
V1/V1 mounts) passes through unchanged. If there is a matching
V2 unit, it requires exactly ONE published DTFS physical-unit
owner, the original public mount ID/slot, valid VFS/MM tables,
and a still-writable VFS policy. It refuses a retained, nonzero
MM extent before invoking `dtfs_intent_first_write_v1553` with
the **exact** `&vfs_mount_aux_base_v1560[slot]` retained basep.

The preexisting v1553 service authenticates both saved 36-bit
identity halves and the original media flags, calls real v1552
MM allocator/pin/physical RBN0 arm or already-armed DIRTY verify,
and only returns success after verified MM release. On return,
v1561 checks the exact original published mount-root word,
expected media word (only ARMED may have newly set), RW policy,
and zero retained MM scratch pointer. If any changed during
sleeping I/O, it refuses the pending DATA/DIR write.

`dtfs_dtc_write` saves the pending physical unit, block and
user-data buffer on its **process-private stack**, because
the MM/device gate may sleep or clobber AC2/AC3. On refusal it
never reaches the actual raw DATA/DIR write. On success it
restores the original physical UNIT/BLOCK/BUFFER before the
ordinary BCACHE invalidate and raw DTC transfer. The versioned
RBN0 write-ahead code continues to use `dtfs_dtc_write_jump`
directly so a marker write cannot recursively arm itself.

## Executed acceptance

`daimos-dtfs-intent-mount-v1561.sh` links the actual production
PDP-6 mount/owner bridge; only the independently tested lower
v1553 physical/MM call is a **strict call-boundary oracle**.
It checks **35 native cases PASS and 13 unsafe source mutations
rejected**, including exact later-slot `basep`, V2/V1 coexistence
refusal, legacy multiple mounts, foreign roots, public mount-ID,
original media/owner preservation, RO refusal, physical error,
failed MM cleanup retaining the pointer, changed root/media or
RO state during sleeping I/O, false successful MM cleanup,
invalid unit/table and retired stale V2 slots.

The fixture must keep its test-case pointer in a separate test
word: AC10 is legitimately used internally by the production
bridge across calls and is restored only on return. A previous
test-ABI mismatch was corrected before acceptance, not hidden.

`daimos-dtfs-v2-ro-write-guard-v1555.sh` still runs 12 actual
source-linked native write-veneer cases, with **nine unsafe
mutations rejected**. Its lower bridge oracle deliberately
clobbers AC2/AC3, so two added mutants verify that the physical
block and data-buffer ABI survive the v1561 invocation. The
existing mandatory V2 read-only veto mutants remain rejected.

`daimos-dtfs-armed-gate-v1554.sh` **23 native cases/eight
mutants PASS** against the actual already-armed physical gateway.
`daimos-dtfs-owned-scratch-real-mm-v1552.sh` exercises the actual
PDP-6 MM allocator, pin/unpin/free and reallocation/shortage
with the real owned wrapper: PASS. `daimos-dtfs-write-path-
coverage-v1559.py` still finds 11 known guarded/raw callsites
and rejects five unsafe bypass/recursion mutations. Complete
KCC full-profile KCORE and DTFS MRES assemble/fold/link PASS.

Reproduce from `daimos-testkit`:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-intent-mount-v1561.sh
sh tests/validation/daimos-dtfs-v2-ro-write-guard-v1555.sh
sh tests/validation/daimos-dtfs-armed-gate-v1554.sh
sh tests/validation/daimos-dtfs-owned-scratch-real-mm-v1552.sh
python3 tests/validation/daimos-dtfs-write-path-coverage-v1559.py "$DAIMOS_REPO"
```

## Non-negotiable boundary

This proves the linked source and native call/owner interfaces,
not the real physical RBN0/DATA atomicity. No production V2
writable mounting or DATA/DIR transfer was enabled; the existing
v1555 V2 veto runs first. A real Type-551 guest with partial
DATA writes, tape replacement/reinsertion, cold boot and a
proven media generation/quiescence contract remains necessary.

The final exclusive CLEAN marker/unmount must prevent any new
FILE/cwd/PIPE/swap ownership while sleeping and prove original
72-bit identity and all physical write completion before a slot
can retire. Existing VFS owner rechecks alone are insufficient
for that transaction. P0-B **OPEN**; P0-A complete; P1-C separate.
