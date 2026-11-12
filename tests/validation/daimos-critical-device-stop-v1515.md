# KCORE v1515: authoritative critical-device-loss fatal stop

Date: 2026-11-12. Native PDP-6 instruction test. Scoped implementation
of the **terminal dispatch mechanism**, not an automatic detector of
permanent device disappearance.

## Policy

Non-removable storage medium loss is device loss. A permanently lost
device or storage provider serving the boot root or BACKSTORE is fatal.
An individual bad block is not an entire lost device; a transient PI
controller error or watchdog timeout does not prove loss. If a device
serves both critical and optional filesystems, the critical owner wins.
An unavailable device serving only non-root mounts must not halt KCORE.

The fixed-KCORE leaf `kcore_critical_device_lost_v1515` accepts only
authoritative confirmed critical-device ownership: AC1=1 for boot root,
AC1=2 for BACKSTORE. A different AC1 is a caller programming error.
This entry has **no caller yet**, intentionally: current Type-270 and
Type-167/236 drivers return generic negative completion for both
temporary PI errors and watchdog timeouts. These are not reliable
offline/permanent-loss classifications. Never dispatch this leaf from
a generic -1 return or an error counter threshold.

On entry the leaf disables global PI using the established PDP-6
`CONO 0004,000400`, then HALTs at a distinct linked instruction
address for each reason. The HALT operand is `.` and continuation
loops back to the same halt. Literal `HALT 4`/`HALT 5`/`HALT 6` were
explicitly rejected in native testing because they set the PC to
low-core addresses 4/5/6 instead of a safe self-halting address.
No storage I/O, KINIT, private process stack, filesystem unmount,
owner release, console string or extra state is needed.

## Native PDP-6 acceptance

`daimos-critical-media-stop-v1515.{s,sh}` source-links the exact
fixed-KCORE assembler into `p10run` with three controlled reasons:

- Root reason: simulator HALTs at linked root-specific HALT symbol.
- BACKSTORE reason: simulator HALTs at linked swap-specific symbol.
- Unknown reason: simulator HALTs at invalid-caller symbol.

For each, the verifier compares the actual SIMH `HALT instruction,
PC:` to its independently linked symbol and requires a code address
at or above octal 001000. The normal test continuation is not
executed. Three executed negative variants replace the relevant
HALT with `POPJ 17,` and are all rejected. The source contract also
checks PI disable and all three continuation guards. **All six
native cases PASS.**

The complete fixed KCC KCORE builds and links with the source.
A controlled original/modified relink using identical other
objects and fold plan gives **+11 fixed instruction words, +0
permanent data words** (`__kcore_low_end` difference 11 decimal).
The older baseline map is not used for this measurement because
the checkout has separate uncommitted changes already affecting
the full KCORE footprint.

## Remaining acceptance

**OPEN:** authoritative hardware/controller/volume device-loss
classification (distinct from transient I/O failures) and its
integration with root/BACKSTORE owner routing; physical critical
device-disappearance and exact fatal PC proof. Genuine controller
unavailability should not bypass the existing bounded I/O timeout.
Non-root device recovery and identity/cache revalidation remain
separate P1 gates. This v1515 acceptance alone does not mean that
detaching the physical drum automatically causes a fatal stop.
