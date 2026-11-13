# KCORE v1531: checked administrative DTFS replacement

Date: 2026-11-13. Feature correctness, not optimization.

## Real 256K PDP-6 KCORE/PID1 test

The new real-guest program
`tests/target/daimos-dtfs-admin-replace-v1531.c`
boots through the actual PTR Stage-1, a TSFS DTC0-DTC2
root, fixed KCORE and installed optional DTFS/TSFS MRES.
The host uses versioned, private stamped native DTC3
tapes and the v1530 process-private SIMH script.

The PID1 test asserts the following native syscalls:

1. Mount native DTC3 RW and create/open/write a real FILE.
   CHMOD successfully commits native metadata and CHDIR
   holds a cwd reference. Root's destructive admin calls
   against an unpoisoned FD/mount are refused, as is a
   request to discard the TSFS root slot.
2. Physically DETACH only DTC3 at a CTY checkpoint.
   Force a real metadata WRITE to fail and verify the
   mounted FSINFO is now denied.
3. Reattach the **original same stamped 72-bit tape**.
   Slot replacement fails while the FILE/cwd is owned.
   Ordinary CLOSE fails, retaining the descriptor.
   Explicit `DROP_FD` releases only the selected poisoned
   FILE; a repeated CLOSE or DROP still fails.
   An outstanding cwd still prevents replacement.
4. Change cwd back to TSFS root. With all references now
   gone, replacing the slot still fails for the original
   DTVOL1 identity, which could contain partially written
   data or directory blocks. No same-ID self-repair.
5. The host physically DETACHes DTC3 and ATTACHes a
   separately generated **different** fully stamped native
   DTFS volume. Two nonzero 36-bit ID halves, DTVOL1
   marker and checksum, and distinct full 72-bit identity
   are verified by a host tool before admission.
   The kernel reads the physical replacement directory and
   RBN0, validates the complete format and distinct ID,
   checks all process references again and retires the
   poisoned slot WITHOUT SYNCing the old damaged volume.
6. FSINFO sees the vacated slot, a normal fresh native
   DTFS mount succeeds on the replacement, the original
   old FILE name is absent, normal UNMOUNT succeeds, and
   the independent TSFS root remains fully functional.

The actual guest reports:

```text
DTFSADMIN V1531 START
DTFSADMIN V1531 READY_DETACH
DTFSADMIN V1531 WRITE_FAILED
DTFSADMIN V1531 READY_RETURN
DTFSADMIN V1531 SAME_REJECTED
DTFSADMIN V1531 READY_REPLACE
DTFSADMIN V1531 RETIRED
DTFSADMIN V1531 PASS
```

The full-guest runner and the host ID verifier both PASS.
Neither the guest, DTFS provider nor the physical Type-551
I/O are replaced by test shims.

## Source-linked native owner/mutation oracle

`daimos-dtfs-admin-owner-v1531.sh` extracts production
`vfs_dtfs_poisoned_slot_v1531`,
`vfs_dtfs_discard_slot_v1531`, its actual
`vfs_unmount_owner_check_v1523`, the production
`file_mount_busy_v1523` scanning stable u-areas,
`file_dtfs_abandon_fd_v1531`, `file_find`, and
`file_node_from_fd` into a real PDP-6 assembly image.

The oracle tests two real-format 0410-word process
u-areas, including an independently owned **swapped**
process with no resident user VM. Its FD15 and cwd
independently block replacement even when PID1 has no
descriptor. PIPE and swap references refuse before
physical verification. An in-flight physical provider
call injects a remote FILE owner after the initial
precheck; the post-provider precommit recheck refuses
without releasing the mount or its identities. Only
after explicit removal of every owner does replacement
retire the VFS slot and clear all three MM words.

The oracle also checks that native/write-poisoned
mounts alone are eligible, never clean or merely
READ_SUSPECT media, non-DTFS providers, invalid
slots, or a non-native personality. Individual
poisoned FD drop and repeated drop denial are
independently verified.

Four deliberately unsafe production-source mutations
must fail the *executed* PDP-6 oracle:

* bypass initial owner scan;
* bypass final post-I/O owner recheck;
* bypass physical replacement verifier;
* change the WRITE_UNCERTAIN guard.

The first draft oracle set its failure stage **after**
the first assertion; a mutation that caused failure
at that assertion could accidentally look like
`main() == 0`. This was corrected in the test:
the failure witness is set before the first call.
All four mutations are now rejected. This was a
test-oracle defect, not a KCORE fix.

## Scope and unfinished administration

The v1531 administrative syscall is an **explicit,
destructive replacement operation**. It does not
repair damaged media, recover discarded FILE contents,
force another process's descriptor closed, kill
an owner, bypass the swap/PIPE reference check, or
trust matching 72-bit IDs as proof of good user data.
Old data requires external recovery. A real multi-
process physical full-guest administration test is
still a useful later strengthening; the production
all-process scan is source-linked/native accepted,
and v1526 separately verifies actual cross-process
physical ownership.

The existing v1529 mid-block physical write test,
v1528 failed-write quarantine, v1527 changed/original
media identity-return and DTC4 isolation, and v1526
cross-process FILE/cwd lifetime tests all pass on
the v1531 full production rebuild.

No new fixed process table or persistent RAM data
is introduced. The feature adds fixed KCORE code
and optional DTFS MRES code, measured in the
corresponding v1531 full image. VERSION 0.5,
strict 32K placement/optimization gate HOLD.
