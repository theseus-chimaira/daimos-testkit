# v1545: full-guest secondary DSK270 and DRM236 D6FS I/O failure

Date: 2026-11-13. KCORE P0-A, feature completion only.

The accepted v1544 PDP-6 native 24-case/six-mutant D6FS test proved
source-linked reader/adapter/root isolation, but not full physical
secondary mounts. The new v1545 physical guest discovered a real
KINIT ABI mismatch: the DSK direct-adapter MINIT slots called raw
DSK MRES services with `(unit, sector, buffer)` instead of passing
through the fixed KCORE `dsk270_read_sector`/`dsk270_write_sector`
physical-address converters. It first appeared as a mounted secondary
whose FCB could not be read **before detach**. KINIT now binds all
four relevant DSK slots through the correct fixed wrapper, matching
the already-correct DRM236 binding.

## Executed tests

Native `daimos-d6fs-minit-dsk-abi-v1545.sh` checks the actual KINIT
source assignments for exports 7, 8, 11 and 12, rejecting four
raw-MRES binding mutations. It then executes the full native PDP-6
`fs_backing.s` direct adapter and `dsk270.s` address encoder against
the raw MRES `(encoded address, buffer)` contract, both ordinary
and root-marked READ/WRITE. A direct-to-MRES native mutation is
rejected. The native verifier exercises real instructions, not only
source grep. All PASS.

Full guest `daimos-secondary-d6fs-fullguest-v1545.sh dsk` and
`... drm` build entirely isolated 256K KCC PDP-6 D6FS-root images.
The testkit creates a real four-member D6FS secondary set with
installed `mkdsk`/`mkd6fs`, checks the entire set using production
`d6fsck`, then derives the 14-word read-only mount handoff from
all actual DBOOT descriptors and matching clean superblocks with
`daimos-secondary-d6fs-media-handoff-v1545.py`. There is no
magic guess or kernel-only mount shortcut. Six corrupted-media
and false-handoff mutations are rejected by
`daimos-secondary-d6fs-handoff-negative-v1545.py`.

1. `dsk`: selected D6FS ROOT on DRM236 DR0..DR3, secondary D6FS
   on DSK270 DSK0..DSK3. Actual PID1 `dsys_d6fs_mount` succeeds;
   FSINFO identifies mount ID2/provider6; secondary file opens.
   After real SIMH DETACH DSK0..DSK3, the first secondary file
   data READ returns an error but KCORE does **not** HALT. A new
   selected-root file DATA read succeeds. **PASS.**
2. `drm`: selected D6FS ROOT on DSK270 DSK0..DSK3, secondary D6FS
   on DRM236 DR0..DR3. Real mounted second filesystem, DETACH of
   only secondary DR0..DR3, negative secondary file READ, healthy
   independent selected-root DATA read. **PASS.**

Each guest uses normal KCC libc syscall veneers and real D6FS
provider/VFS/FS_BACKING, with no injected low-level I/O status.
The host requires unique ordered stages `START`, `MOUNTED`,
`READY_DETACH`, `SECONDARY_FAILED`, `ROOT_ALIVE`, `PASS`, rejects
any `FAIL_*`, and rejects any simulator `HALT instruction` marker.
Its earlier TSFS-root variant failed mount because that boot
did not install D6FS MRES; that unaccepted test was redesigned
as valid independent D6FS-root/secondary-controller pairs.

## Reproducer

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-d6fs-minit-dsk-abi-v1545.sh
sh tests/validation/daimos-secondary-d6fs-fullguest-v1545.sh dsk
sh tests/validation/daimos-secondary-d6fs-fullguest-v1545.sh drm
```

The complete media-validation and mount/physical records are held
in each versioned temporary work directory when
`V1545_KEEP_WORK=1` and `DAIMOS_TSFS_KEEP_WORK=1` are set.

## Remaining P0-A

The negative mounted-secondary hardware matrix is now physically
accepted for both Type-270 and Type-236. Combined shared-device
ROOT/BACKSTORE failure (root logical error vs swap logical error,
unambiguous HALT reason and no false owner releases) is separate
and remains OPEN. No permanent memory, user syscall or filesystem
format changes were required for v1545.
