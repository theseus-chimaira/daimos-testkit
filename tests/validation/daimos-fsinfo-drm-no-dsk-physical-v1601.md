# P1-D v1601: DRM-root physical inventory without DSK270

Date: 2026-11-15. Full original 128K PDP-6 guest, four real Type-236
DRM236 D6FSR2 members, selected root switch `3` (DRM). Before KINIT
MINIT, the disposable SIMH dofile disables the actual DSK270 controller
(`set dsk disabled`) and removes all four DSK attachments. Type-167
DP and Type-236 DR0..DR3 remain enabled. This is the physical reverse
of v1597 (DSK selected, no DP/DR). No production module services or
FSINFO/KINIT words are patched.

The first exploratory run was launched before the stronger v1601 linked
word and preboot descriptor capture had been added; it completed its
guest but could not satisfy the subsequent oracle's required file
contract. **It is not acceptance evidence.** The completely rebuilt
second run with all captures installed from the outset PASSes:

* Genuine original DRM236 MINIT row `OK`, no DSK270 `OK` row;
  original D6FS, BSET and MEMFS provider loads.
* Original `dsys_fsinfo(-1,NULL)` returns **2**, not 6. Root is
  provider 6, public ID 1; MEMFS `/TEMP` is provider 4, ID 2;
  ordinary slots 2/3 are **invalid**, not empty phantom drives.
* Both original MM-backed mount-array addresses are nonzero,
  distinct and within actual physical RAM. Source-matched addresses
  come from the exact KCORE map and are read after guest HALT:
  `vfs_mount_limit` `023703`, `vfs_mount_root_base` `023702`,
  `vfs_mount_target_base` `023701`, namespace `024270` (octal).
  Capacity word on original halted KCORE is **2**.
* Four physical DRM media are 8192 sectors each; each original
  drive descriptor and D6FSR2 member marker survives the full
  guest unmodified. Four distinct original member IDs, consistent
  geometry `000001+017377+000400` (octal), exact preboot/postboot
  RBN0 comparisons.
* Original XIP RUN/WAIT/EXEC test completes `XIP-RUN-PASS`,
  `STATUS:0` and normal HALT, with no simulator-device/listener error.
* Independent oracle rejects **10** corrupt physical/controller/
  capacity/MM/guest-evidence cases: invalid descriptor, duplicate
  identity, missing FSINFO result, invented DSK probe, DSK left
  enabled, wrong root switch, forged original capacity six, null
  MM slab pointer, overwritten preboot root descriptor and lost XIP.

Actual v1601 evidence is retained under
`$TMPDIR/daimos-fsinfo-drm-nodsk-v1601.GUnDWg` including original
guest/build, exact `kcore.map`, four DRM raw images, preboot header
capture, source-linked addresses, SIMH transcript and the files
`v1601-physical-verification.txt` and `v1601-raw-oracle.log`.

Reproduce with installed current `$PDP10_PREFIX` toolchain:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
V1601_KEEP_WORK=1 sh \
  tests/validation/daimos-fsinfo-drm-no-dsk-physical-v1601.sh
```

The existing source-linked v22 inventory test also now requires that
the DRM-only root produce exactly two slots and that absent ROOT or
asymmetrically installed READ/WRITE services never create phantom
mounts. The unchanged native KCORE FSINFO test v1492 still checks
the exact assembly handler and original MOUNTS/DF consumer loops.

This completes the formerly missing reverse controller-absence P1-D
physical case. It does not prove 26 physical installed devices, or
replace the independent dirty/write-through and loaded-simulator
timing P1-C acceptance. Production KCORE, RAM, ABI, MRES and media
format are unchanged. VERSION 0.5; strict 32K/optimization HOLD.
