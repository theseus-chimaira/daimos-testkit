# P1-E v1651: original 48K sampled MM occupancy and fragmentation

Date: 2026-11-17. **Physical original-trace accounting PASS.**
The simulator evidence is the already accepted v1643 six-child
PDP-6/TSFS/DTC3 compressed-PURE/real read-error and recovery
workload. v1651 does NOT build a new kernel or run a new guest.
No production C/assembly, MM geometry, ABI, MRES or RAM changes.

## Reproduction

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export DAIMOS_REPO=/path/to/DAIMOS
export PURE_PEAK_BUILD_V1651=/path/to/original/v1643/build
export PURE_PEAK_TRACE_V1651=/path/to/original/v1643/trace.clean
sh tests/diagnostics/pure-peak-ram-v1651/run-v1651.sh
```

The runner first repeats the FULL original v1643 physical
source-linked audit: actual compressed secondary source,
real DTC3 read failure, exact owner/pin rollback, same-medium
reattachment, successful later restore and all six EXIT/WAIT.
It then reopens the original MM physical extent/arena dumps
using the established sorted-descriptor parser. Every extent
must lie inside the same original managed arena without
overlap and all occupied+free words must add to arena size.
Owner/type/pin counts are independently asserted for each
stage. There is no guessed global heap counter.

## Exact source-matched 48K measurements

The original managed-MM arena is physical octal
`042561..140000` (31,375 decimal words). Resident KCORE,
fixed allocations and other core below the arena lower
boundary are not individually itemized here.

| Stage | Occupied decimal | Free decimal | Largest free gap | KERNEL_DYNAMIC |
| --- | ---: | ---: | ---: | ---: |
| B | 27,163 | 4,212 | 883 | 2,331 |
| A | 27,163 | 4,212 | 883 | 2,331 |
| FULL_PINNED | 27,668 | 3,707 | 883 | 2,196 |
| ROLLED_BACK | 23,572 | 7,803 | 4,096 | 2,196 |
| LATER_FULL | 27,668 | 3,707 | 883 | 2,196 |
| Z | 4,958 | 26,417 | 26,417 | 862 |

At B/A: six physical `MM_TYPE_PACKED_PROCESS` owners of
`006600` octal (=3,456 decimal) words each and one complete
4,096-word parent PROCESS. At FULL_PINNED, one earlier plain
child has completed: five PACKED suffix owners remain, and
one separate 4,096-word PROCESS destination is pinned
alongside its authoritative PACKED suffix. KERNEL_DYNAMIC
occupancy decreased by 135 decimal words. Thus the
measured B/A -> FULL_PINNED delta is precisely
`4096 - 3456 - 135 = +505` occupied words.

The 883-word largest free gap is **less** than the mandatory
`02000` octal (=1,024 decimal) APR alignment/granularity;
the largest contiguous remainder beginning on a valid
`02000` boundary is only 640 decimal words. Therefore this
particular checkpoint cannot fit another minimal APR
even though 3,707 decimal managed words remain free in total.

At ROLLED_BACK, the exact 4,096-word destination is freed
and the source is unpinned and still authoritative; 4,096
more words become free compared to FULL_PINNED. Later FULL
again occupies an exact same-size destination for another
compressed child; the process population differs but the
MM totals match. The final Z snapshot contains only the
parent PROCESS and seven dynamic MM extents, no child owners.

## Negative controls

Three separately altered copies of the original physical
FULL_PINNED trace must be rejected by the same accountant:

* One-word fabricated arena extension below the original
  lower bound, changing total capacity without an owner.
* One-word understated real KERNEL_DYNAMIC descriptor.
* False absence of the original full-APR destination pin.

The test asserts an actual running accountant refusal for
each variant; no production source or authentic trace is
modified. The physical read/recovery auditor has its own
independent source/pin/error falsifications.

## Boundary

**Accepted:** sampled occupancy/free/fragmentation for these
six original v1643 48K MM checkpoints, including simultaneous
source/target pin and precise changes in other owner classes.

**Not accepted:** a continuous full runtime maximum; kernel
storage or scratch outside the managed arena; equal-source
PURE-ON versus PURE-OFF net savings for this enlarged v1643
guest; 32K/64K BCACHE layouts; or KA10 VM. The earlier v1639
48K matched ON/OFF gain of 1,314 decimal free words is
independent evidence from a different, smaller guest.
Do not transplant its 1,758-word MRES comparison directly
into this v1643 trace without matched binary/layout evidence.

PURE remains disabled by default. P1-E OPEN and strict
32K whole-KCORE optimization HOLD.
