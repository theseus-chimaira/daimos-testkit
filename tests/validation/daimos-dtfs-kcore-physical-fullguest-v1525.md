# Real PDP-6 KCORE secondary DTFS physical feature acceptance, v1525

Date: 2026-11-13. This is a physical KCORE feature test, not
a mock or a userland feature addition.

## Test architecture

`daimos-dtfs-kcore-physical-fullguest-v1525.sh`
compiles `tests/target/daimos-dtfs-physical-gate-v1525.c`
with the installed KCC PDP-6 compiler and source-matched
production `crt0`, `syscall`, `u` and `text` objects,
then embeds its DXR in a disposable **physical TSFS-root**
test manifest as `/SYSTEM/INIT` (real PID 1). The same
actual KINIT, fixed KCORE, optional DTFS/TSFS MRES,
PDP-6 Type-551/136 controller, and real `dsys_*` syscalls
execute. Neither the C test nor the host harness replaces
a KCORE provider, VFS dispatch or physical tape read.

The disposable test TSFS root is reduced to the minimum
necessary records to avoid unrelated minutes-long loading
of LOGIN, DSH and external MOUNT commands from DTC0.
The test does **not** add an installed module to KCORE.
Its DTC3 medium comes from the current host `mkdtfs`,
but the script independently checks the fully stamped
72-bit `DTVOL1` marker, two nonzero independent 36-bit
halves, complement, and exact native reserved owner
at **C dir[14] = PDP-6 assembly octal +016**. The
physical guest MUST still admit the directory and
RBN0 by actual native Type-551 transfers.

## Reproduced source defects and corrections

Before v1525:

- Real guest: KINIT `DTFS LOADED`, DTC3 directory read
  happened, but `DTFSGATE V1525 FAIL MOUNT` occurred.
  Production DTFS native mount inspected
  `fs_block_workspace+014` (index 12 decimal) rather
  than `+016` (index 14 decimal), conflicting with
  both host and target native formatters.
- With that source offset corrected, the real guest
  reported MOUNTED but `FSINFO` and `GETCWD` failed
  to reconstruct the TSFS-backed mount path. Inspection
  found `tsfs_parent` and `tsfs_parent_name` used
  `JUMPN` against `tsfs_parent_common`'s successful,
  nonzero parent vnode. Both must use `JUMPL` (negative
  error only). The native source-linked
  `daimos-tsfs-parent-v1525.sh` accepts actual decoded
  TSFS parent and SIXBIT name, and rejects both old
  executable polarity mutations.
- Existing source-linked native v1519/v1520 mock
  directory fixtures duplicated the incorrect +014
  owner-word offset. They now encode the actual native
  directory format, and v1519 rejects a dedicated
  `+016 -> +014` negative mutation.
- The formerly installed host `mkdtfs` was stale and
  emitted zero RBN0 instead of a stamped ID. Current
  production host source was rebuilt and installed
  as versioned `mkdtfs-v1525`; the old executable was
  preserved separately for comparison.

## Final checked physical guest

Full isolated **256K KCC tape-root image** linked successfully
with `DTFS LOADED`. The final booted one-process guest
executed all of:

1. `DTFSGATE V1525 START`: genuine PID1 after KINIT
2. `MOUNTED`: native stamped DTC3 admitted by KCORE
3. FSINFO slot 0: provider 7 /; slot 1: **provider 5
   at /MOUNT/DT0**
4. `STAT` and `GETCWD` on mounted DTFS succeed
5. `BUSY_REFUSED`: UNMOUNT fails with cwd on DTFS,
   while FSINFO still shows its mount
6. Opens a real FILE descriptor on the mounted directory;
   cwd leaves; `FD_REFUSED`: UNMOUNT still fails
   solely because the open FILE holds the vnode
7. Closes FILE; final UNMOUNT succeeds; FSINFO
   confirms mount slot absent
8. `DTFSGATE V1525 PASS` and full guest script PASS.

Actual result transcript is under
`$TMPDIR/daimos-v1525-kcore-pid1-file-cwd-physical-r8.log`
and the matching retained v1525 guest CTY log.
The test is a real **single-process** physical
cwd/FILE lifecycle acceptance; a second live
process and physical DTC detach/replacement/dirty
faults remain future P0-B tests.

## Size and change boundaries

The fixed optional DTFS/TSFS MRES remains
`DXR image=003746 bss=000002` octal, exactly
the same size as the previous image. No new
resident KCORE instructions, MM data words,
additional persistent state or on-media
format have been introduced. DAIMOS VERSION
remains 0.5; strict 32K KCORE is on HOLD.

Primary source report:
`DAIMOS/design/kcore-dtfs-physical-mount-v1525.md`.
