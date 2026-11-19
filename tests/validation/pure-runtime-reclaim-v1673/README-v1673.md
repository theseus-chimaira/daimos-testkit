# v1673 physical PDP-6 RAW PURE reclaim acceptance

This is an opt-in testkit-only source-matched test of the unmerged
DAIMOS PURE branch. It does not alter production KCORE or INIT.

## Scenario

Build a disposable three-member TSFS PDP-6 image at 48K words with
PURE MRES and bitmap mode3 disabled. Test-only PID1 launches nine
sleeping PURE children and then attempts a tenth RUN under memory
pressure. The tenth RUN must be refused with a spare process slot,
while nine earlier children are held in PACKED RAW-suffix form. The
original MM extent, arena, process table, storage-mode, u-area and
backing state is sampled through three real CTY barriers A/B/C.
The child fixture calls `dsys_sleep(1800U)` before EXIT; the PID1
post-test idle loop uses `dsys_sleep(600U)`. The host CTY checkpoint
timeout defaults to 900 seconds of host wall time, not simulated time.
The final WAIT checkpoint must occur after all children exit. The parent WAITs all nine children;
final MM ownership must exactly
match the baseline. The RAW suffix saves 128 physical words per child,
1152 words total. No disk or drum swap is attached.

Run both general and strict swapless profiles. The strict profile must
not link disk SWAP MRES. `compare-v1673.py` requires physical MM and
process ownership equality between both variants at all three phases.
`run-negative-v1673.sh` checks the same oracle with five corrupted
physical transcripts and a forged summary; every mutant must fail.

## Run

From a clean source-matched DAIMOS v1672 development worktree, with
PDP10_PREFIX installed and a writable TMPDIR:

    DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/pure-runtime-reclaim-v1673/run-physical-v1673.sh

Set `KEEP_TEST=1` to retain temporary source-built images and evidence.
`V1673_ONLY_VARIANT=general` or `strict` is for debugging only: it
skips paired comparison and cannot count as full acceptance.

## Boundaries

The test validates stable 48K physical snapshots, not continuous
instruction-level peak, 64K, bitmap mode3, KA10, disk-root boot or
all PI6 fault paths. It must not be represented as those acceptances.

## 2026-11-19 stable-checkpoint acceptance (PASS)

Accepted against DAIMOS PURE development source `ae84bb37`, not merged
mainline. Two separately retained 48K physical PDP-6 console reports,
from the GENERAL and STRICT builds, were passed together to the original
`compare-v1673.py` oracle. A second independent retained general/strict
pair also passed the same comparison. All four JSON reports have
SHA-256 `d1065373bc172be41ecbb859261f056ae5c5361336c607631ceb5eefdf2118a6`.
The original general console was independently remeasured with its
source-built maps and matched the retained JSON byte for byte; the
strict console was independently remeasured by the negative test driver.

| Stage | Free MM words | Largest free extent | Resident APR | PACKED RAW |
| --- | ---: | ---: | ---: | ---: |
| Baseline | 27441 | 27441 | 1 | 0 |
| Pressure | 2794 | 1641 | 1 | 9 |
| Post-WAIT | 27441 | 27441 | 1 | 0 |

Nine physically distinct PACKED RAW owners each save 128 words, for
1152 reconstructed PURE words no longer retained as physical process
images. A tenth real RUN was refused despite 2794 total free words and
a spare process slot: the largest aligned free extent was only 1641
words, too small for its 2048-word APR image. All owners and free
extents returned exactly to baseline after nine EXIT/WAIT completions.

The source-linked `run-negative-v1673.sh` was run against the original
strict 48K physical console, source-built fixture/kernel symbol maps
and report. **PASS:** five deliberately corrupted originals (storage
mode, PACKED extent type, saved executable backing, CTY release,
SYS_MEMINFO) were rejected, and a separately forged JSON summary was
rejected. Neither test modifies the production guest or KCORE.

Reproduction: `make test-pure-runtime-reclaim-v1673` with the matching
DAIMOS source worktree selected by `DAIMOS_REPO`. The evidence above
is from retained physical runs plus independent recomparison/replay,
**not** one newly completed paired simulator invocation. Its acceptance
scope is therefore stable 48K general/strict RAW-mode checkpoint
reclamation. Continuous high-water, synchronous PI6 fault recovery,
bitmap mode3, other root classes, KA10 and production mainline merge
remain outside this gate.
