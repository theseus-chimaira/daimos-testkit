# KCORE v1516: exact TSFS root-member identification without new RAM

Date: 2026-11-12. Scoped acceptance of compact physical DECtape
root-set metadata and the optional TSFS membership predicate. This
is **not** automatic tape-removal detection and does not yet call the
existing v1515 critical-device HALT entry.

## Original ambiguity and corrected representation

TSFS maps at most eight logical DECtape members through one existing
36-bit per-mount `tsfs_file_shape` word. Eight three-bit fields occupy
bits 0..23. Unused fields encode zero, which is also a valid **physical
DTC unit zero**. A naive scan of all eight slots cannot determine whether
unit zero is a real root member or only uninitialized trailing padding.

KINIT already checks each member's physical DTC unit during TSFS boot
selection. The v1516 handoff retains that *exact membership mask*
in bits 24..31 of the **same** packed word; bits 32..35 remain zero.
The existing low 24-bit logical-to-physical map is unchanged. Duplicate
physical units remain rejected during `build_handoff()`. The former
second scan in `tsfs_boot_select()` is replaced by extracting that
validated mask. There is no on-media format, mount-slab size, KCORE
resident data, persistent process state, or ABI change.

The unchanged TSFS extent reader shifts the member map right by at most
21 positions and masks the lowest three bits. Therefore the new high
eight bits cannot affect a legitimate logical member's selected unit.

The optional `tsfs_root_owns_dtc_unit_v1516` routine accepts a physical
unit in AC1 and uses the **current namespace root**, its public mount ID,
the published mount capacity, and the existing `tsfs_file_shape_base`
word. It returns +1 only for a selected TSFS-root physical unit, zero
for a different provider or a non-member, and -1 for invalid unit/
root mount/metadata state. It does not treat a negative tape I/O
status as evidence of removal.

## Executed tests

`daimos-tsfs-boot-eight-v1.sh`: host-KINIT test PASS for an eight-member
permutation using units 0..7, a single-member root on *physical unit 0*,
and a two-member root on physical units 0 and 5 with metadata on member
one. Each test checks the *entire* 36-bit handoff plus the existing
`tsfs_boot_unit_mask_v22()` result. The two-member mask is `041` octal,
not inferred from the trailing zero slots.

`daimos-tsfs-root-member-v1516.sh`: native PDP-6 source-linked helper
PASS for physical units 0 and 5 in a two-member root, unrelated DTC
units 1 and 7, a different disk-root provider, invalid -1/8 unit
values, a forbidden mount slot with plausible data, missing media
word or pointer, a one-member unit-zero root and an eight-unit root.
Four *executed* source mutations are rejected: wrong membership-mask
shift, wrong provider, missing public-mount-capacity check, and
accepting an invalid zero mask.

`daimos-tsfs-slab-v15.sh` PASS after changing its stored-extent
fixture to carry the new high membership mask, thus checking that
ordinary cross-member data reads still use the original selectors.
`daimos-tsfs-multiextent-v1.sh` PASS. Their standalone test-only
linkage now supplies the root/mount symbols needed by the optional
query and a fail-closed unused compressed-decoder stub (these
oracles exercise stored extents). No production stubs or shortcuts
were added. Legacy `daimos-tsfs-d6lz-v1` is an old D6LZ oracle,
not counted as a passing v1516 runtime regression after the
current D6codec decoder migration.

The complete isolated **32K GCC tape-root KINIT** links with the new
boot handoff and DTFS/TSFS MRES. The strict existing fixed-KCORE
32K size gate reports `__kcore_low_end=023241` octal against the
required `<020000` octal. This remains a **FAIL** of that gate,
not v1516 acceptance. The v1516 optional TSFS code is not in
fixed KCORE; no claim that it caused the existing KCORE overage.

The independent **256K KCC full tape-root KINIT** also builds and
links successfully, including the optional TSFS MRES with the
source-linked `tsfs_root_owns_dtc_unit_v1516` symbol exported.
Both full target builds used separate disposable `$TMPDIR` build
trees and did not overwrite the production build or unrelated edits.

A controlled link comparing old/new optional TSFS objects with
identical other MRES objects and corresponding independent fold plans
shows the next TSFS symbol displaced by +27 instructions and a later
read routine displaced by +25. Thus approximately **25-27 new
optional TSFS MRES code words**, and no new permanent data words.
This code exists only in tape-root-capable profiles; fixed KCORE
has no additional instructions from v1516.

## Remaining P0 boundary

The actual Type-551/Type-136 status remains ambiguous: SIMH uses
`DTB_ILL` for an unattached unit selected by `CONO`, but the same
bit also describes an illegal command/unit. A tape search timeout,
PI status error, or absent RBN does not alone prove a tape was
removed. No generic -1 or retry-count threshold may dispatch v1515.
An authoritative unit-removal/change signal and its verified routing
through the selected TSFS root set to the fatal leaf, with distinct
non-root DTFS fault/recovery tests, remain OPEN. The new helper only
answers the ownership portion of that question.
