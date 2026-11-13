# KCORE v1529: interrupted Type-551 data-block write acceptance

Date: 2026-11-13. This is a **real simulated PDP-6/Type-551
physical media** test: production KCORE, storage driver, DTFS
provider, FILE/VFS, MM mount tables, CTY and native DTC3 tape
format all execute without substituted I/O callbacks. The
only fault source is a diagnostic-only SIMH Type-551 modifier.

## Preconditions and independent diagnostics

The guest uses the existing full 256K KCC tape-root image
with native DTFS/TSFS optional MRES installed from DTC0-2.
Its PID1 mounts a properly stamped DTVOL1 DTC3 volume RW
at /MOUNT/DT0, opens /MOUNT/DT0/PARTIAL, truncates to two
words and writes the two distinct old values. The test
launches a real native 36-bit physical RBN0145 transfer.

Two independent tests were added:

* daimos-dtfs-resize-new-file-v1529.sh source-links the real
  native resize routine and checks allocation of an EMPTY
  file at sizes one and two; PASS.
* daimos-dtc-next-block-v1529.sh source-links the real
  Type-551 PDP-6 storage implementation and physically
  writes then reads RBN0145 without VFS; PASS.

Before the interrupt is armed, host DETACH flushes the
genuine native DTC3 image. The host copies it to
prewrite-v1529.tap and verifies both old data words are
in physical RBN0145. It reattaches the original image,
and uses the diagnostic command:

    set DTC3 PARTIALWRITE=0145:1

The versioned PDP-6 SIMH test build contains the diagnostic
only when compiled with PDP6_DTC_PARTIAL_WRITE_V1529.
Both forward and reverse Type-551 FNC_WRIT data paths
count words whose actual 36-bit image value changes.
After the first CHANGED word, a subsequent attempted write
raises Type-551 information error (DTB_ILL). The fault
remains armed across controller retries so recovery cannot
silently finish the partially completed transaction.
Standard simulator builds contain no injected code path.

The guest rewinds the same FILE to offset zero, attempts
to replace both data words, and checks the raw syscall
returns an error. The controller prints:

    DTC3: V1529 PARTIALWRITE block 0145 after 1 changed word (2 physical words)

At READY_VERIFY the host again interrupts the simulator,
DETACHes DTC3 to flush the modified 18-bit-lane tape file,
and runs daimos-dtfs-partial-media-verify-v1529.py. It
compares all 128 physical 36-bit words, checks that the
native block header did not change, and requires EXACTLY
ONE of the two requested data slots to carry its new value.
Every other physical word, including the other requested
data slot, must retain the original preimage value.
The actual accepted run reports:

    PASS v1529: two seeded words on real DTC3 RBN0145
    PASS v1529: physical RBN0145 changed only data slot 1; the other requested new word remains old

After reattaching this same, now partly damaged DTC3, real
KCORE FSINFO and pathname STAT continue refusing the
original mount. Both CLOSE attempts refuse without
relinquishing its FILE; ordinary UNMOUNT also refuses.
The unchanged TSFS root remains available as provider 7.
Real PID1 reports STICKY_CONFIRMED and PASS. The full
physical test runner exits zero.

## Invalid initial diagnostic simulator builds

Early exploratory full-guest runs failed seed writes,
even on the previously accepted v1528 ONE-word control.
Those simulators were compiled with a replaced CC command
that accidentally discarded SIMH's default platform
feature macros. These failures were not valid evidence
of a production DAIMOS defect. The test simulator was
rebuilt with the complete default SIMH CC flags, with
only the v1529 test macro appended. That full-flags build
is installed as a versioned pdp6-v1529r5 via local.tar.gz
under PDP10_PREFIX and independently passes the original
v1528 physical quarantine control.

Two concurrent guest runners were also found sharing a
mutable prebuilt image and stopped; that overlapping
attempt was discarded. The verified v1529 acceptance
uses a versioned, independent 39 MB clone of the exact
same production full-KCC image, with its absolute SIMH
media paths rewritten to that clone. The controlled
full guest has only one owner of its DTC3 tape.

## Scope

This is an actual partly modified simulated physical
DECtape block, not a mocked negative I/O result or a
preemptive DETACH before writing. It proves the existing
WRITE_UNCERTAIN safety barrier and original FILE/mount
ownership survive a matching-ID return when one data
word is new and another is old. It does not implement
an administrative repair or forced-discard protocol.

There is no change to production KCORE, optional
DTFS/TSFS MRES, runtime RAM, disk/tape format, VERSION
or the 32K HOLD. The only implementation is optional
simulator fault-injection source and testkit code.
