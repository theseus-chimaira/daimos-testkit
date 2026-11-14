# v1553: authenticated native DTFS first-write state transition

Date: 2026-11-14. KCORE P0-B feature preparation, **not installed in
the live DTFS provider**, physical cold-boot acceptance still OPEN.

## Source implementation

`system/kernel/fs/dtfs_intent_first_write_v1553.s` is a genuine
PDP-6 assembly routine requiring an existing exclusive
`fs_provider_reg_call` DTFS/TSFS/D6FS provider lease. Inputs:

- AC1: zero-based VFS mount slot, **not** a raw physical unit;
- AC2: pointer to the provider-retained one-word MM scratch base,
  initially zero, which survives a refused v1552 MM release.

The routine rejects negative/out-of-range slots, null scratch
owner pointers, retired or wrong-provider root vnodes, wrong
root mount IDs, foreign-personality media, missing DTVOL2 format
flags, sticky READ_SUSPECT/WRITE_UNCERTAIN, either zero half of
the previously admitted identity, and a retained nonzero MM
scratch base. It reads the complete physical DTC unit from the
already published per-mount media word, and both original ID
halves from the MM-backed shape/extent slots. It does not trust
an arbitrary user-provided volume identifier or unvalidated
physical unit number.

For an unarmed mount, it calls the **actual v1552 source-defined
MM pin + v1551 raw physical RBN0 write-ahead transaction** through
the one provider lease. On success, and only after full MM
scratch release, it rechecks the exact original media word and
sets `DTFS_MEDIA_INTENT_ARMED_V1553` in that word. It preserves
the high 18-bit UID/GID owner, lower physical unit and all
existing tags. Failed arming, identity changes or cleanup
refusal cannot set ARMED or authorize the first DATA/DIR write.
All MM cleanup refusals retain the exact provider scratch basep.

The spare right-half state bits are:

```
0100000 DTFS_MEDIA_FORMAT_V2_V1553
0040000 DTFS_MEDIA_INTENT_ARMED_V1553
0200000 DTFS_MEDIA_RD_SUSPECT_V1522
0400000 DTFS_MEDIA_WR_UNCERT_V1522
```

These are **provisional runtime flags**, not new persistent bits
or a standalone persistent database. Only the physical v1551
RBN0 `WRITE_INTENT` record persists after unmount or reboot.

## Executed native acceptance

`daimos-dtfs-first-write-v1553.sh` runs the production v1553
assembly on the actual PDP-6 CPU with the v1552 MM/physical
service represented by an exact ABI/status oracle. This
service was independently tested against the real MM and v1551
raw-I/O boundary in v1551/v1552.

**18 native cases PASS:** first verified arm; already-armed
fast path; legacy media; READ_SUSPECT; WRITE_UNCERTAIN; other
provider; incorrect mount ID; retired mount; missing high/low
identity; outstanding MM scratch allocation; physical arm
failure; arm failure retaining its scratch owner; changed
media word while I/O sleeps; absent scratch pointer; out-of-
range mount; foreign personality; and preservation of an existing
18-bit UID/GID owner in the media word. Each case checks the
exact return, lower-provider calls, final media bitset and
retained MM scratch pointer.

**13 source mutations rejected** by the actual native oracle:
bypassing format/suspect checks, wrong provider/mount, stale
root, missing identity halves, dropping retained MM ownership,
bypassing physical arming, ignoring errors or a mid-transaction
media-state change, skipping ARMED publication, and wrong raw
DTC unit. The C media constants and PDP-6 assembly constants
are checked for equality before test execution.

An early test failed because the fixture used `050102000000` as
a wrong mount; that changes **local vnode kind**, not mount ID.
The correct alternate mount ID is `050201000000`. Fixing the
fixture allowed the source to reject an actual wrong mount.
No production code check was weakened.

Reproduction:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-first-write-v1553.sh
```

## Unresolved production prerequisites

This source is deliberately **not linked into DTFS MRES**. The
live provider still uses the old DTVOL1 mount and write logic.
The v1553 ARMED fast path is an in-memory transaction marker;
it is **not physical revalidation** if the operator exchanges
the DTC medium after the first data write. Before this entry
can authorize subsequent production writes, add a generation-
aware or independent physically read-backed DIRTY/identity
check for already-armed requests.

The production provider must additionally publish the DTVOL2
format flag only after full CLEAN mount admission, allocate and
retain the one-word scratch base, call the gate from every
mutating DATA/DIR path without recursive raw RBN0 writes, and
perform final CLEAN only after preventing new FILE/cwd/PIPE/
swap owners from appearing during any sleeping unmount I/O.
The existing VFS final owner recheck is not, by itself, an
exclusive quiescence barrier for a sleeping CLEAN seal.

Only after those conditions hold can booted Type-551 partial-
write/reinsertion/reboot tests close P0-B. P0-A remains complete;
P1-C remains open. Strict 32K/optimization HOLD.
