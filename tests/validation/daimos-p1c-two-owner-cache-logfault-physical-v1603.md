# P1-C v1603: composite two-owner PI6, physical torn LOGSTORE and live BCACHE

Date: 2026-11-15. Final P1-C physical intersection on TWO independent
original 128K PDP-6 cold boots. Full KCC-built D6FS-root guest,
four genuine Type-236 DRM236 D6FSR2 root members, mapped interleaved
BACKSTORE VOLUME, LOGSTORE and MEMFS snapshot. This is a real
hardware-simulator program, not an in-memory model or a fake FSINFO.

## Disposable observers, unmodified production ownership

The testkit creates an isolated copy of current DAIMOS KCORE and
composes the established v1584/v1585/v1588/v1592/v1577/v1590
source-linked test-only observers. The original process scheduler,
PI6 timer service, PI2 Type-236 completion, BACKSTORE ownership,
MM/BCACHE and filesystem/LOGSTORE implementations remain original.
The two sleeping swap-backed children are genuinely awoken by one
original PI6 timer event each; no PI is simulated by the observer.
One test-only selected post-physical-write LOGSTORE completion error
produces a genuinely written uncommitted physical record, after
which the original same-slot LOGSTORE retry commits it. This is NOT
a spontaneous magnetic-media failure. The private clean D6FS BCACHE
is already populated with actual file data and must be unchanged
through BOTH physical transfers and subsequent cache fetches.

The separate original post-swap-DMA checked-release refusal forces
the original transaction's MM/BCACHE/bitmap/process rollback rather
than a false RESIDENT publication. Original LOGSTORE and MEMFS
snapshot remain durable between two independent boots.

## Actual two-boot results

Both cold boots PASS the full independent source-linked oracle:

| Original physical witness | Boot 1 | Boot 2 |
|---|---:|---:|
| Distinct original SLEEP/DISK owner slots | 6 / 7 | 6 / 7 |
| Genuine original PI6 wakeups for each | 1 / 1 | 1 / 1 |
| Genuine mapped swap READ attempts | 5 | 5 |
| Type-236 PI2 completions | 1120 | 1120 |
| Checked post-DMA owner rollbacks | 1 | 1 |
| Original physical torn LOGSTORE write observed | 1 | 1 |
| Same-slot physical committed LOGSTORE retry observed | 1 | 1 |
| D6FS private BCACHE physical nonzero data words | 28 | 28 |
| 128-word cache differences after torn / committed writes | 0 / 0 | 0 / 0 |
| Original BCACHE fetch after each write | HIT / HIT | HIT / HIT |
| Real MM-backed clean cache slab (octal) | `377577` | `377577` |

The physical persistent MEMFS/LOGSTORE image is written on boot 1
and restored on boot 2; final snapshot sector is DR3:`017777`
(octal). The mapped volume has 3648 pool blocks, 283 other nonzero
BACKSTORE sectors, exact real member geometry, and unchanged
process/backing ownership after the checked refusal. The original
guest performs its normal explicit HALT on both boots (PC `022011`
octal); no controller-busy or unavailable-root error is accepted.

The independently verified post-HALT original KCORE symbols for
both cache data and the two timer owners must match the exact
freshly built `kcore.map`. This explicitly rules out success by
userland console markers alone or stale linked addresses.

The combined verifier rejected **44 deliberately corrupted
observations**: 15 new cache/LOGSTORE data and stage changes,
16 inherited two-owner/timer/rollback ownership errors, and
13 inherited raw physical mapped-volume/swap/PI2 errors. It
requires each actual original transfer and its independent success,
not only aggregate status.

## Reproduction and exact evidence

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
V1603_KEEP_WORK=1 sh \
  tests/validation/daimos-p1c-two-owner-cache-logfault-physical-v1603.sh
```

The accepted physical original evidence is retained at:

```
$TMPDIR/daimos-p1c-composite-v1603.Z4dCmb
$TMPDIR/daimos-p1c-v1603-fullguest-run1.log
```

See `persistent/boot-1/simh.log`, `boot-2/simh.log`, the exact
four-member `persistent/guest/build/system/boot/pdp6/drum` images,
`kcore.map`, `v1584/v1585/v1588/v1592/v1590-linked-addresses.txt`,
`v1603-physical-verification.txt` and `v1603-verifier-output.txt`.

## Acceptance boundary

This is the missing P1-C **recoverable** cross-provider fault during
two original PI6 process owners and populated clean cache, not a
claim of two simultaneously active swap DMA operations or an
unrecoverable BACKSTORE request followed by further service. Actual
fatal owned-BACKSTORE READ policy is separately proven on mapped
VOLUME v1599 and independent direct DEVICE v1600: a single selected
real PI2 READ leads to the required reason-2 HALT, with all owner
records retained, no postfatal recovery or false RESIDENT publish.

This combines with the v1602 actual native D6FS write-through
failed/successful DSK270/DRM236 control and cache isolation (4 cases,
5 executed mutants), v1596 real separate DTFS outage and writable
MEMFS, v1590 source-authentic physical LOGSTORE torn/retry with
populated cache, and the v1592 two-boot loaded repeatability
regression. **P1-C feature acceptance is complete**, not a change
to the separately open physical Type-551 media-retention P0-B gate,
the P1-E KA10 review, or the strict 32K optimization HOLD.

No production KCORE, storage driver, filesystem, MM, ABI, or on-disk
format change was needed. All v1603 probes and source overlays live
solely in the daimos-testkit checkout.
