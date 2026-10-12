# D6FS host-repair durable-write interruption matrix (2026-10-12 v1)

Inputs: the preserved *faulted* four-member PDP-6 SIMH disk image containing
orphaned FCBs 0451 and 0452, and a DAIMOS source tree containing
`tools/host/d6fsck.c`. The runner **never writes to input media**. It clones
all four `.dsk` members for each trial, verifies the original orphan state,
compiles the host checker with `D6FSCK_TEST_FAULTS`, and aborts its repair
process immediately after the Nth `fflush` + `fsync`-completed physical
block write. It then restarts normal `d6fsck -r`, checks clean metadata,
checks a second repair makes no changes, and verifies input checksums.

The runner discovers the actual number of repair writes by increasing N until
a full repair finishes without an injected abort. Its upper bound defaults
to 256, and can be changed using `D6FS_CUT_MAX`. Every interrupted run must
exit 99. No hardware media write barriers or power cuts are simulated.

**Validated results on the preserved fixture:**

- Original host d6fsck: all **48** durable-write interruption points resume
  successfully to CLEAN; original image unchanged.
- Changed-block-only host d6fsck from DAIMOS v2 repair update: all **3**
  remaining interruption points resume to CLEAN; second repair idempotent,
  original image unchanged.
- All runs use cloned media and real D6FS on-disk structures, not abstract
  FCB state booleans. The existing host fault hook executes after a successful
  `fsync`, but this is not a hardware power-loss guarantee.

Run with `DAIMOS_REPO=/path/to/DAIMOS`,
`D6FS_DISK=/path/to/faulted/disk`, and `TMPDIR=$HOME/tmp`.
The runner prints its artifacts directory, which retains per-cut logs and disks.

This demonstrates **offline repair restartability for this specific
zero-extent orphan case**, not transaction-atomic file creation or boot-time
replay. A separate test verifies unique-extent ownership and refuses to
alter cross-linked metadata.
