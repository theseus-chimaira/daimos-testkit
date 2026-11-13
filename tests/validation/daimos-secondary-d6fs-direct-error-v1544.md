# v1544: native DSK270/DRM236 D6FS root/secondary error isolation

Date: 2026-11-13. KCORE P0-A acceptance refinement. No new
runtime syscall, new resident device mapping, or optimization.

## Purpose and scope

The v1538 source-linked test had already proven that a failed D6FS
read or write on the selected published root HALTs, while an
otherwise identical failed secondary mount returns an error. It used
a stand-in for the final physical adapter. The v1 D6FS direct-
backing test had separately proven the DSK270/DRM236 mapper and
physical unit selection. v1544 connects both layers in one native
PDP-6 execution, including the actual `fs_backing.s` adapter.

`daimos-secondary-d6fs-direct-error-v1544.sh` extracts and assembles
the exact current D6FS runtime reader, cache-commit path, generic
backing descriptor, direct DSK/DRM selector, v1538 ROOT classifier
and the v1515 distinct ROOT/BACKSTORE HALT leaf. The test fixture
patches the eight physical adapter call/jump slots as the actual
MINIT mechanism does. Only the final physical controller outcome
(success or exhausted failure) and minimal BCACHE behavior are
test doubles. The real public D6FS mount IDs are 1 (selected ROOT)
and 2 (unrelated secondary).

The 24 actual PDP-6 CPU cases are:

- Direct DSK270 and DRM236, each selected root and secondary mount,
  each READ and WRITE, each success and final hardware failure:
  16 cases. Root errors HALT at the **ROOT** address; secondary
  failures return normal error (NULL for block read, -1 for write).
- Secondary DSK270 and DRM236 three-member INTERLEAVE set, each
  READ and WRITE with final failed hardware transfer: four cases.
  In both cases the real mapper must select physical unit 3 and
  physical block 0101 (octal); neither may HALT KCORE.
- Logical out-of-range READ or WRITE on secondary DSK/DRM or
  selected root DSK/DRM: four cases. No physical request and no HALT.

Every executed case also checks the actual lower physical callback's
controller kind, unit number, block number, I/O count, and (for
nonfatal completion) BCACHE store count. Secondary failed I/O must
leave `mfsdev_storage_errors+4` (root-only D6SET errors) unchanged,
and must never increment the D6SET logical read/write counters.
Six unsafe actual-source mutations are rejected:

1. Omitting the root reader error gate.
2. Treating a secondary mount as the published root.
3. Misrouting DRM requests to DSK instead of DRM.
4. Mislabeling a secondary direct request as root D6SET accounting.
5. Routing root errors to the BACKSTORE rather than ROOT HALT.
6. Picking the wrong member in a three-member INTERLEAVE set.

Run:

```
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
sh tests/validation/daimos-secondary-d6fs-direct-error-v1544.sh
```

All **24 cases and six mutants PASS**. The older v1513 nonroot
media-return checks and v1 direct-backing adapter checks are also
retained as independent regressions.

## Physical acceptance not claimed

This verifies full D6FS-to-physical-adapter native instruction
composition with a test-controlled final controller result. It
does **not** attach a real second D6FS filesystem through its
validated handoff or simulate real DSK270/DRM236 I/O detach in a
booted full guest. The existing `dsys_d6fs_mount` ABI requires a
validated transient 14-word handoff; no production userspace
scanner currently produces that handoff. Merely detaching an
unused secondary device would not prove the desired behavior.

The remaining physical negative test must genuinely mount such a
filesystem, read an uncached file block, physically detach its
own DSK/DRM device, observe a failed read without any ROOT or
BACKSTORE HALT, and prove independent selected-root progress.
Do not invent or hardcode a supposedly validated handoff merely
to make a physical test pass. Root/BACKSTORE shared DEVICE/VOLUME
physical fault ownership remains open as well.
