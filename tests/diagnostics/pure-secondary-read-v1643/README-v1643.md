# P1-E v1643: real secondary DTFS executable read failure during FULL

Status: original physical PDP-6 48K test ACCEPTED 2026-11-17.
No production KCORE, PURE, MM, VFS, DTFS, TSFS or ABI change.

## Source-derived executable fixture

`prepare-v1643.py` derives the original v1636/v1637/v1638 six-child
C89 guest, retaining every original PIPE, two private mutable DATA
sentinels, no-growth BRK, seventh-RUN refusal, EXIT-057, six exact
PID/EXITED/status-057 WAIT checks and final `Z`. It adds only an
initial PID1 source-seeding step and changes the five compressed
children's RUN paths from `/SYSTEM/COMP` on the selected TSFS root
to `/MOUNT/COMP` on a *secondary* native DTFS filesystem.

The original immutable TSFS root has `/MOUNT` but not
`/MOUNT/DT0`. The first diagnostic attempted the nonexistent
deeper mountpoint and failed *before* RUN (first observed `!f`,
then the exact `!1` mount error). The underlying approach was
valid; the test fixture was corrected to mount on the existing
directory without changing VFS or requiring a writable root.

PID1 mounts the actual stamped DTC3 native DTFS volume RW,
checks FSINFO public mount 2/provider 5, copies the original
compressed root DXR file through ordinary `dsys_read_words`/
`dsys_write_words`, closes both FDs, CHMODs executable 0555,
performs a normal owner-safe CLEAN unmount and remounts the SAME
physical reel read-only. No VM or MM word is injected. The
selected namespace ROOT always remains original TSFS mount 1.

The final original guest prints:

    aaaaaax[B013470/042501]<010000+010000>
    [A013470/042501]{013470-013470}LwwwwwwZ

and exits through normal simulator HALT. Original B/A MM has six
distinct unpinned PACKED_PROCESS children, owners 2..7, with
physical `006600`-word retained suffixes. The extra source code
increases the DXR2 PURE text to `001227` octal words. The
original `vm_pdp6_pure_range_v1604.h` computes omitted prefix
`(text+020) & ~0177 = 001200` octal and retained raw
`010000-001200 = 006600`. Do not transplant v1638's `007000`
raw suffix length into this different executable source.

## Original physical DTC3 outage and same-reel recovery

`replay-v1643.sh` makes fresh private copies of all four DTC
media, leaving DTC0..2 physically attached throughout. It
uses source-authenticated original KCORE/MRES maps and DXR
opcodes, and stops at actual bounded FULL loader PC `035252`.
At this stop compressed child slot3 simultaneously owns:

| Slot | Octal physical extent | MM type | Pins |
|---|---|---|---:|
| 3 | `111200..120000` | PACKED_PROCESS source | 1 |
| 3 | `120000..130000` | PROCESS full destination | 1 |

The test host DETACHes ONLY DTC3 and confirms the simulator
reports that drive not attached. The original v1391 transaction
then returns from its loader with `MM_ERR_INVAL = -4` at actual
service return PC `032461`. The original source RAW suffix
is still `111200..120000`, now unpinned, and the temporary
PROCESS destination is completely freed. No other child remains
pinned and the TSFS namespace root identity is unchanged.

Testkit reattaches the exact same physical DTC3 private reel.
The next observed original compressed FULL callback returns 0
for slot4, with pinned source `101200..110000` and separately
pinned destination `120000..130000`. Eventually **all six**
original child PIPE/mutable-sentinel/EXIT and exact parent
WAIT checks complete, terminal `Z`, normal HALT. The final
source-linked MM has **no child PROCESS or PACKED owner**.

The test therefore demonstrates failure-atomic FULL cleanup
after a genuine non-root device-backed read failure and normal
recovery with the identical returned volume. It does not rely
on the v1641 simulated loader return error. The original v1538
ROOT fail-stop policy is retained; attempting this on selected
root DTC0..2 would correctly HALT, as proved separately in v1642.

## Running the tests

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-secondary-read-v1643/run-v1643.sh

    PURE_SECONDARY_BUILD_V1643=/path/to/guest/build \
        sh tests/diagnostics/pure-secondary-read-v1643/replay-v1643.sh

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_SECONDARY_BUILD_V1643=/path/to/guest/build \
    PURE_SECONDARY_TRACE_V1643=/path/to/replay/trace.clean \
        sh tests/diagnostics/pure-secondary-read-v1643/run-audit-v1643.sh

The source-matched full-extent auditor PASSes and also rejects
two forged machine traces: an unfreed source pin at failure
return and a fabricated successful return from failed FULL.

The test doesn't claim a DIRECT sampled value of the DTFS
READ_SUSPECT bit or time-resolved peak memory. The original
v1522 read-error identity barrier is a separate accepted source-
linked test. Additional P1-E gates remain: immutable executable
mutation/unmount while PACKED, PI6/uncertain MM errors, broad
32K/64K profiles, and matched transient system peak RAM.
PURE is still OFF by default; strict 32K size optimization HOLD.
