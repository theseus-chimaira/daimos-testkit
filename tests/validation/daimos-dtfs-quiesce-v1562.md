# DAIMOS native DTFS V2 quiescence acceptance v1562

Date: 2026-11-14. Scope: native production-source helper and real
VFS unmount control flow, with controlled provider completion.
No physical Type-551 CLEAN marker is written by this stage.

## Reproduction

```sh
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-quiesce-v1562.sh
sh tests/validation/daimos-dtfs-quiesce-unmount-v1562.sh
```

The helper runner extracts the real v1562 leaves from `vfs.s`
without reimplementing their decisions. The 41 actual PDP-6 cases
include normal, sealed, legacy and foreign-provider admission;
packed FILE metadata; retired, mismatched and out-of-range mount
slots; missing MM slabs; owner-preserving begin, refusal and end;
sticky media error bits and register ABI. Seven unsafe source mutants
are rejected by the independent native oracle. **41/41 PASS, 7/7
unsafe mutations rejected**.

The second fixture executes the real `vfs_unmount` instructions
through its owner checks, sleeping SYNC callback, final MM check,
barrier release, unlock and retirement. The callback models a
foreign process attempting to acquire a new FILE owner while the
unmount is suspended. The test verifies that quiescing V2 refuses
it but legacy V1 still relies on the original final owner scan;
failed SYNC and sticky media errors do not retire a mounted volume.
**12/12 PASS, 3/3 unsafe source mutations rejected.**

The older v1514, v1523 and v1560 source-linked fixtures were
updated only to understand the one extra process-stack word and
the additional helper references. They retain their existing
assertions and mutation checks and all PASS. The v1554, v1555,
v1556, v1559 and v1561 native regression suites also PASS.

Full KCC auto-root 256K image generation and optional DTFS MRES
assemble/fold/link PASS. KCORE fixed placement grew 152 TEXT words,
with no added permanent DATA/BSS/mount-slab word. Strict 32K
permanent-size acceptance remains intentionally on HOLD.

## Limits and next validation

The test's simulated concurrent OPEN is not proof of scheduler
preemption or cross-class PIPE/swap owner admission. No final
physical DTVOL2/DIRTY-to-CLEAN marker is sent to the controller,
and no real media-generation/exchange or partial-write/cold-boot
test is claimed. The production v1555 V2 READ-ONLY veto remains.
P0-B is still OPEN; see
`DAIMOS/design/kcore-dtfs-quiesce-v1562.md`.
