# v1371: full standard D6FS distribution grouped D6CODEC cold boot

Run from the `daimos-testkit` checkout:

```
DAIMOS_REPO=/path/to/staged/DAIMOS \
    sh tests/validation/d6codec-fulldist-v1371/run-v1371.sh
```

`PDP10_PREFIX` defaults to `$HOME/cross`; `TMPDIR` defaults to
`$HOME/tmp`. The complete run preserves the production KCORE,
D6LZ36 decoder, linker objects, userland and filesystem images.
Its output lives under `$TMPDIR/d6codec-fulldist-v1371` plus the
explicit v1370/v1368 test-only prerequisite workspaces.

## Actual normal distribution, not a copied short file list

The runner first repeats the full v1370 PDP-6 grouped cold-boot,
linked MRES and original-codec control tests. It then stages the
real DAIMOS Makefile dependencies (KCC source/ABI, manual pages,
ASMUTILS source, config, native DAS three-part executables). A
versioned auxiliary Makefile is loaded *after* the production
Makefile so variable references expand against its actual current
values. No build rule is added to the production Makefile.

`build_full_root_v1371.py` asks the real boot Makefile to expand its
`D6FS_ROOT_ARGS` and uses those exact `-D` and `-f` pairs for the
new root. At this checkpoint that expansion has **237 files and
29 directories**, including 89 DXR executables and 148 binword
files. Every referenced input must exist. All 71 filenames that
originally selected `.d6lz.dxr` binaries are redirected to newly
encoded **grouped DXR2** counterparts generated from their *plain*
original linked DXRs. Every conversion is independently decoded,
and its executable entry, image and relocations are checked. A
source already carrying the COMPRESSED flag is rejected rather than
passed through as a possible legacy file. The other 18 DXRs,
including INIT, MOUNTALL and optional toolchain bootstrap programs,
remain uncompressed as in the original manifest.

The test creates only filenames containing `grouped-v1371.dxr` under
the isolated output tree. No legacy filename is overwritten. A
versioned inventory records the original filesystem path, codec
classification and SHA-256 digest for every imported file.

The real `mkdsk`, `mkd6fs`, `logstore` and `d6fsck` utilities create
four pristine DSK270 member images using the complete expanded
Makefile root directory/file list. The host checker reports a
**CLEAN D6FS with 336 FCBs**, versus the 15-node v1370 smoke root.
All this content is served by native actual D6FS/VFS rather than
synthetic provider stubs.

## Native PDP-6 full-root acceptance

`run_boot_v1371.sh` uses the already verified grouped KCORE and
guarded Stage-1 KINIT image from v1370, but boots from a fresh copy
of the **new complete v1371 root**. It does not reuse the original
CLEAN disk image after a boot: a normally modified D6FS superblock
can be DIRTY, so a second boot must have its own fresh media.

The simulator boots DAIMOS through the real Stage-0, Type-136
DECtape grouped Stage-1, KINIT, 27 grouped-map MRES packages,
DSK270 D6FS, INIT, grouped LOGIN and grouped DSH. It authenticates
ROOT on CTY and exercises commands on the full root:

- `ECHO V1371FULL`: verifies a separate guest output line.
- `LS /SYSTEM/EXEC`: verifies installed LOGIN, DSH, GREP, WC, MAKE.
- `CAT /CONFIG/FSTAB`: verifies the actual FSTAB header.
- `GREP MEMFS /CONFIG/FSTAB`: verifies the MEMFS mount line.
- `WC /CONFIG/FSTAB`: verifies the real `3 7 55` count.
- `STAT /SYSTEM/EXEC/DSH`: verifies a regular executable with mode 0555.
- `LS /OPTION/BASE/EXEC`: verifies the installed native DAS, DARC,
  DLINK, OBJDUMP and KCC entries.
- `EXIT`: verifies INIT respawns LOGIN.

These tests require program output and not merely a shell prompt or
the echoed input command. **All checks PASS under PDP-6 SIMH.**

## Remaining format-cutover blockers

The grouped KCORE is still v1367, with +256 linked resident words
in the correctness-first reserved-low-core layout. This milestone
does no instruction-size optimization and does not replace the
production D6LZ36 build or media.

The `D6LZ` executable is still included from the original normal
distribution and remains a **legacy-format writer**; use of it to
create new executables would produce files incompatible with the
grouped-only kernel. The final production change must supply a
native grouped compressor or deliberately remove/replace that
utility as part of an atomic format change. The `DXR_F_COMPRESSED`
bit does not distinguish formats and must not be interpreted as
permission to mix them.

Other open integration gates: actually execute native KCC/DAS
toolchains, test grouped TSFS *root* and restart media, physical
immutable PURE eviction/swap/reload, nested VFS/provider stack
watermarks, controlled device/EOF/corruption failure tests, and
full production image/build wiring. The v1371 test checks all
grouped DXRs on the host and representative real user commands,
not native execution of every one of the 71 programs.
