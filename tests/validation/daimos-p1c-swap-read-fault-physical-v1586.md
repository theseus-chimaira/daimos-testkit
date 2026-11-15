# P1-C v1586: physical swap READ PI2 fault during independent snapshot overlap

Date: 2026-11-15. One full real 128K KCC PDP-6 guest, the original
four-member DR0..DR3 Type-236 D6FSR2 root VOLUME, original BLOCKSET
INTERLEAVE mapped BACKSTORE, original MEMFS snapshot and LOGSTORE.
This is the **first selected physical swap READ error while an
independently scheduled PI6 swap-in overlaps snapshot I/O** in this
series. It is a fail-stop test, NOT a recoverable rollback test.

## Actual execution and bounded test-only injection

The opt-in `daimos-p1c-swap-read-fault-physical-v1586.sh` builds a
disposable copy of the real production kernel. It uses exactly the
accepted v1584 original slot-0 swap READ/PI2 observers and v1585
actual independent timer PI6 wakeup, without changing the actual
original scheduler/swap/MM/BCACHE/BACKSTORE source. Four 24K-word
private children have real positive swap ownership; all reach
genuine long timed SLEEP. The test-only snapshot entry changes one
already sleeping, disk-backed child's real timer deadline to the next
clock tick. Neither the process state nor the run queue, PI6
request, swap-in syscall or physical controller is shortcut.

After the original independent slot-0 service actually enters
`proc_swap_in`, the original `drm236_runtime_request` binds the
real hardware group of that READ descriptor. Only its **first
actual DR_DONE PI2 completion** is redirected into the original
production `drm236_pi_error` branch. Nothing is returned directly
from the backing gateway, and no invented completion occurs.
The original Type-236 finish routine publishes the failure and
increments original `mfsdev_storage_errors+5`; the original fixed
`fs_mres.s` BACKSTORE error gate reaches the original v1515 reason-2
fatal HALT. The injector modifies only a disposable source copy,
adds three temporary diagnostic words and never touches permanent
KCORE, fixed RAM, ABI or media format.

## Accepted original post-HALT evidence

The full one-boot physical runner PASSed. Original KCORE-linked
SIMH witness words and the independent raw 36-bit media oracle report:

| Witness | Original value |
| --- | ---: |
| Exact original BACKSTORE reason-2 fatal HALT | `004011` octal |
| Selected real Type-236 unit and physical sector | DR1, `017506` |
| Actual logical INTERLEAVE BACKSTORE block | `000431` octal |
| Original PI6 timer armed, original timer service woke child | 1, 1 |
| Original sleeping selected slot | 6 |
| Original independent slot-0 swap-in starts | 1 |
| Real mapped swap READ requests | 1 |
| Original matched physical swap READ PI2 | 1 |
| Original total snapshot-window Type-236 PI2 | `0343` octal |
| Original successful DISK-to-RESIDENT publication | 0 |
| Test-only selected fault injection count | 1 |
| Original Type-236 controller error count | 1 |
| Original generic logical storage error counter | 0 |
| Original process swap blocks still owned | `01650` octal |
| Original BACKSTORE blocks still allocated | `01734` octal |
| Original snapshot still in progress at fatal HALT | all-one 36-bit word |
| Selected descriptor retired, selected fault rearm | 0, 0 |
| Original pending synchronous swap READ marker | all-one 36-bit word |

The independent host verifier checks the linked KCORE symbol map
for *every* post-HALT witness, then independently computes the
selected hardware group `0375060` from the actual Type-236 DR1
physical sector and all four D6FSR2 on-media layout descriptors.
The selected sector is inside the mapped BACKSTORE tail and contains
real backing payload. The original final MEMFS v2 header on DR3
sector `017777` remains invalid (zero first word). All four physical
D6FSR2 descriptors are byte-identical to their pre-boot images;
268 other BACKSTORE sectors contain independent nonzero data.

Fifteen deliberately corrupted linked/witness/physical-data
variants are rejected: lost injected PI2, absent original driver
error, uncleared fault arm, absent original PI6 wake, missing
independent swap-in, missing swap READ, absent matching real PI2,
false resident publication, lost process ownership, bogus hardware
group, missing mapped VOLUME, premature snapshot exit, erased real
READ payload, falsely committed v2 header, and modified D6FSR2
member layout. The full runner returned success.

## Scope and remaining acceptance gates

The selected hardware DR_DONE event is original, while the error
bit is deliberately injected in disposable PI2 source: this is NOT
evidence that physical drum media naturally failed. The test proves
the critical fail-stop and correct failure ownership for **one
independent swap READ during real MEMFS snapshot overlap**. It does
not prove recoverable owner/MM/BCACHE rollback, second/late swap
sector failures, or snapshots that recover after an error. P1-C
remains OPEN for those transaction gates. The v1585 intermediate
180-second timeout remains an independently documented stability
question; this v1586 physical run passed without a new timeout.
P1-D/E remain OPEN; VERSION 0.5, low end `024364` octal and strict
32K/optimization HOLD remain unchanged.

Full retained evidence, real guest transcripts, KCORE map, selected
physical member and exact verifier result:
`$TMPDIR/daimos-p1c-swap-read-fault-v1586.5lg2J3`.

Reproduce from daimos-testkit:

```
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
export TMPDIR=${TMPDIR:-$HOME/tmp}
V1586_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-swap-read-fault-physical-v1586.sh
```
