# KCORE physical media test isolation v1530

Date: 2026-11-13. Testkit infrastructure correctness,
not a KCORE implementation or new FS recovery policy.

## Root cause: mutable shared KCC build

The physical v1525-v1529 guest runner took an immutable
prebuilt production KCC boot image as input, but then
overwrote `$build/media/dtc0.tap` through `dtc3.tap`,
created `dtc4.tap` in the same directory, and rewrote
`$build/boot.headless.ini`. When two separate full-guest
jobs shared that same build, one job could replace or
flush the other's currently attached DTC3 image. A
v1529 post-write tape verifier could then report missing
seed data unrelated to the actual kernel transfer.
The Type-551 and DTFS production behavior must never
be inferred from that invalid, aliased test medium.

## Corrected fixture

`daimos-dtfs-tape-root-mount-v578.sh` now keeps
**all four boot-attached DTC0-DTC3 tape images**
inside its process-unique `$work/media` directory,
named `dtcN-v1530.tap`. The DTC4 second-volume
test image is also under the private work directory.
The host creates the disposable root TSFS tapes and
the native DTFS/DTVOL1 identity in that directory.
For a disk-selected root, it copies any unchanged
initial DTC media into that directory rather than
attaching the prebuilt writable file in place.

The generated `boot-headless-v1530.ini` is private.
It preserves every command from the production KCC
`boot.ini`, while replacing only the four exact
absolute DTC0-DTC3 paths. The existing conditional
DTC4 injection, monitor hot-swap, debug output,
root image selection, bootstrap, DCS0 and CTY paths
remain unchanged. The reattach commands and the
preimage/postimage verifier use the **same private**
DTC3 pathname as the boot script. A prebuilt KCC
image and its media/boot configuration are now
read-only fixture inputs even if multiple jobs start
from the same directory.

The test does not mock physical I/O, delay a simulated
interrupt, or change an on-media block format.
It repairs the test fixture's ownership invariant.
Unique work directories and private SIMH scripts also
prevent one guest from deleting or rewriting another's
in-progress command file.

## Positive regression gates

The v1529 real Type-551 partial-block run confirms:
real physical RBN0145 seed (two old data words),
one changed 36-bit data word in the failed transfer,
the other old word unchanged, a negative KCORE
write return and sticky WRITE_UNCERTAIN across
the same 72-bit-ID tape return.

The older v1528 real failure-and-return test, v1527
real DTC3/DTC4 same/different-medium return test,
and v1526 real two-process FILE/cwd ownership
test are independent physical regressions and
must continue to pass with the same v1530 fixture.

There are no changes to DAIMOS production code,
runtime RAM, MRES text/BSS, boot format or
VERSION 0.5. The strict 32K gate remains HOLD.
