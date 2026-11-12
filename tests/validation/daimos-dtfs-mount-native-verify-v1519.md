# KCORE v1519: native DTFS mount verifies real media before VFS publication

Date: 2026-11-12. Source-linked native PDP-6 acceptance of the
**native-directory format admission gate**. Not a unique-volume
identity mechanism, automatic media-change detector, or full
replacement-tape recovery implementation.

## Correctness failure found in production

The short-lived userspace `DTFSPROBE` validates DTFS format before
the normal shell mount command, but a direct `SYS_DTFS_MOUNT` caller
can bypass that helper. In v1518, `dtfs_mount_unit` validated its
unit/flags and then called `vfs_mount_prevalidated` without reading
or verifying the physical native directory. Worse, a BCACHE hit
on unit/block `DTCn,,0144` cannot prove the tape currently in that
transport is the same tape that generated the clean entry.

The corrected `dtfs_mount_unit_media_ready` validates the native
filesystem *before* calling the VFS publisher. It first invalidates
both shared clean BCACHE tags and clears the shared DTFS directory
identity. The direct, already-MINIT-patched `dtfs_dtc_read_jump`
then issues a **raw physical** read of the native directory block
0144 into the existing `fs_block_workspace`, deliberately bypassing
the normal DTFS cached read veneer and its old clean tags.

The source rejects any negative hardware read, non-native magic
at directory word 0177, incorrect reserved owner for physical
block 0, incorrect reserved owner for the directory's own block
0144, or incorrect three terminal 035 native allocation tags.
These checks match the existing `dtfs_probe_unit` native format
probe and the native `MKFS.DTFS`/`mkdtfs` formatter constants.
They require no new format fields, scratch buffer, process state,
mount slot, data allocation, or ABI change.

The optional foreign TENEX/ITS feature gates remain disabled in
the production native-only build; if enabled in a separate build,
this added directory-format check applies only to native DTFS.

## Executed native PDP-6 validation

`daimos-dtfs-mount-native-verify-v1519.{s,sh}` links the actual
`dtfs_mount_unit` routine, its production saved-register epilogue,
and the real BCACHE invalidation leaf into the PDP-6 simulator.
Only the already-pluggable physical DTC jump and the VFS publication
boundary are controlled by the test. The simulated raw device
callback checks **AC1=physical unit 3, AC2=block 0144,
AC3=fs_block_workspace**, then copies genuine native-format marker
words from a fixture into the shared physical read buffer.

The successful baseline tests all these cases in order:

1. Valid native directory allows VFS publication and media-word
   patching, exactly once and only after one physical read.
2. A different, invalid on-tape directory with bad magic is
   refused even though the old workspace still contains valid
   metadata and BCACHE had a previously clean directory tag.
3. A bad block-zero reserved allocation tag is refused.
4. A bad directory-block reserved tag is refused.
5. Missing terminal 035 native allocation tags are refused.
6. A negative physical read is refused without publishing a
   mount or retaining the old clean identities.
7. The **same valid tape** returning permits a fresh read and a
   subsequent successful mount publication.

Every refusal retains the caller's original output sentinel,
does not call VFS publication or `dtfs_patch_media`, and clears
both clean BCACHE tags plus the shared DTFS directory identity.
The physical read count checks that the gate truly executes
hardware I/O on every attempted validation.

Six executed source-mutant tests are rejected:

- Skipping the physical read and using the old workspace.
- Skipping shared BCACHE invalidation.
- Reversing the magic check.
- Bypassing block-zero reserved ownership.
- Bypassing directory-block reserved ownership.
- Bypassing the three terminal native tags.

All seven native runs PASS. Existing v1518 DTFS failed-read/write
cache recovery, v1490 BCACHE writer ABI/free-refusal, DTFS
chain-walk/create/unlink/rename/directory-field tests also PASS.

## Build and memory measurements

Isolated **256K KCC** full tape-root KINIT and **32K GCC** lowmem
tape-root KINIT, including the production optional DTFS/TSFS MRES,
assemble and link successfully. The separate strict 32K fixed
KCORE gate still FAILS (`023241` octal, must be `<020000`). This
must not be presented as a deployable 32K kernel.

For exact code growth, a controlled old/new link uses identical
fixed-KCORE map, unchanged DTFS/TSFS objects and separate normal
p10fold plans, replacing only the versioned `dtfs_runtime.dobj`.
The next `dtfs_lookup` moves from octal `001704` to `001734`,
a **+24 decimal word** offset. Later `tsfs_mres_dispatch`
and TSFS root-member helper move from `002443`/`002455` to
`002476`/`002510`, respectively, a **+27 decimal word** offset.
The folded net change is therefore **+27 optional MRES code
words, +0 permanent data words, +0 fixed KCORE words**. Existing
VFS and filesystem ABI, on-media layout and VFS mount capacity
are unchanged.

## Important remaining boundary

Native DTFS format validation proves that the physical tape
currently has a structurally plausible native filesystem. It
**cannot authenticate its unique identity**: the existing native
directory contains only common magic and allocation-map markers,
not a unique volume identifier. This change does not authorize
reusing an old vnode, dirty write or FILE handle on a different
tape inserted into an already mounted transport. Nor does it
detect silent media removal that has not caused an I/O failure.

Next P1 work must establish a versioned volume-identity and
open-file lifecycle protocol before claiming automatic replacement
recovery. P0 confirmed physical TSFS root-member removal detection
and v1515 terminal dispatch are still separate and open.
