# P1-C v1599: two real PI6 owners and one physical fatal BACKSTORE READ

Date: 2026-11-15. Full 128K KCC PDP-6 boot from four genuine Type-236
DR0..DR3 D6FSR2 members, original BLOCKSET INTERLEAVE root VOLUME
and mapped BACKSTORE, original persistent MEMFS snapshot/LOGSTORE.
KCORE, scheduler, process swap, MM, D6FS, BACKSTORE and driver
error/fatal paths remain production code. Diagnostic counters and
the selected physical completion fault exist only in a temporary
source copy; no production RAM, ABI, media or kernel changes.

## What the physical guest actually does

The existing v1584 physical slot-0 swap READ/DRM PI2 observer and
v1585 independent PI6 timer observer are combined with the accepted
v1592 two-owner retiming. Four independent 24K-word private children
own actual disk backing and reach real timer-tagged SLEEP/DISK.
At the original MEMFS snapshot shutdown entry, the disposable
observer selects two *different*, previously SLEEP/DISK owners
with nonzero real swap records. Both receive the next original
60 Hz timer deadline. No observer queues RUN, invokes swap-in,
marks a process resident or synthesizes a timer interrupt.

The unchanged original PI6 timer service wakes each selected owner
exactly once, and the independent scheduler's original slot-0
service issues a mapped BACKSTORE READ. The accepted v1586
test-only observer selects its actual DRM236 request descriptor
and reroutes ONE genuine hardware-simulator DR_DONE PI2 completion
to the unchanged `drm236_pi_error` leaf. The original physical
driver then reports its real descriptor failure to the original
critical BACKSTORE gateway, which executes the original v1515
no-return reason-2 HALT. This is a *selected injected failure on
an authentic simulated PI2 path*, not natural magnetic-media loss.
It must **not** attempt recovery or continue serving MEMFS.

## Accepted real guest and physical evidence

The full physical guest and independent linked-address/raw-media
oracle PASS. Critical source-derived post-HALT results:

| Actual source-linked observation | Value |
| --- | --- |
| Two distinct original timed SLEEP/DISK slots | **6 and 7** |
| Original timer-service PI6 wake counts | **1 and 1** |
| First actual original scheduler swap-READ owner | slot **6** |
| Original independently scheduled swap READs and matching DR_DONE PI2 | **1 and 1** |
| Original successful DISK-to-RESIDENT publishes | **0** |
| Selected injected driver errors | **1** |
| Original reason-2 BACKSTORE HALT | **`004011` octal** |
| Original physical Type-236 selected group | `0375060` octal |
| Actual member and physical sector | DR1, `017506` octal |
| Original mapped BACKSTORE logical sector | `000431` octal |
| Original process swap allocation | `01650` octal blocks |
| Original total BACKSTORE allocation | `01734` octal blocks |
| Original MEMFS snapshot state at HALT | in progress |
| Final persistent snapshot header | uncommitted, zero |
| Other nonzero physical backing sectors | **268** |

The oracle derives member/sector/relative logical address from the
actual linked Type-236 request group and all four genuine D6FSR2
member descriptors (not a hard-coded test guess). The selected
physical READ sector has nonzero original backing payload; every
original member layout header remains byte-identical to its
pre-boot descriptor. No false committed snapshot, no rollback
pretence after fatal error, no observed successful RESIDENT
publication. The guest performs a real LOGSTORE append/readback
before the fault. The simulator uses the installed corrected
`pdp6-v1598` Type-551 transport fix; this experiment is on DRM236.

**23 deliberately corrupted evidence cases rejected**: eight
new owner/PI6 identity/wakeup variants and fifteen inherited
original v1586 driver/PI2, fail-stop, MM ownership, root VOLUME,
physical backing payload and false snapshot-commit variants.
The original v1586 single-owner physical report and all its
fifteen negative controls also PASS after verifier extension.

## Boundaries and next work

Both independent owners are actually woken before the first
BACKSTORE READ fails, but only one physical swap READ is in flight
at the fatal boundary. This does not prove two concurrent DMA
requests, post-error continued service or recoverable rollback.
The logical Type-236 mapped VOLUME is the same root/controller
class as v1586; the new acceptance is **two separately awakened
owners present at that exact fatal boundary**, not a new hardware
class. A direct DEVICE-backed AUXSTORE with independent DSK root,
dirty/write-through provider faults, and loaded repeatability
remain separate P1-C tasks. Original owned BACKSTORE service loss
is always critical/fatal under the accepted v1548 policy.

Reproduce (fresh isolated test-only kernel, unmodified production):

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
V1599_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-two-owner-fatal-physical-v1599.sh
```

Accepted retained physical evidence:
`$TMPDIR/daimos-p1c-two-owner-fatal-v1599.OjP5cW`, including
`v1599-physical-verification.txt`, `v1599-verifier-output.txt`,
the exact KCORE map/linked addresses, four physical DR member
images, original pre-boot descriptors and original HALT console.
VERSION 0.5, fixed KCORE low end `024364` octal, 32K optimization
HOLD, P1-E implementation HOLD for KA10 architecture review.
