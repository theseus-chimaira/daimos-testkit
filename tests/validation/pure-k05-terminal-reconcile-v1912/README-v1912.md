# K05 v1912: late reconcilable foreign owner, genuine last-user HALT

Date: 2026-11-24. **Scoped original PDP-6 48K physical PASS.**

## Original guest and physical boundary

Reuse the original source-built v1910 five-child compressed TSFS
guest with EXACT fixed KCORE/PURE from v1906-v1911. No new guest
build, resident state or production source change is required.

The private controller first replays v1911 completely: a genuine
PACKED source `mm_free` returns -5, the test changes one temporary
PROCESS target MM owner3 -> foreign owner2, original parent TERM(3)
refuses, original parent exits, and original children slots 4,5,6
EXIT. Only the quarantined slot3 orphan remains; MM10, three native
slot0 recovery retries separated by `01000` octal PCLK ticks and
one actual PI6 preserve RAW/foreign target/CTX/FDCTL/uarea067.

The verifier separately replays the **exact same** pre-repair
physical trace through the accepted v1911 source-linked oracle,
using a saved v1911 controller script. No second guest or forged
KCORE result is substituted.

## Essential MM-table compaction rule

The original initial owner fault is injected at MM descriptor
word `024725`, where original provisional PROCESS target
`120000..130000` belonged to slot3. After the normal children
EXIT the original MM extent table compacts: its active MM10
target owner field is now physically at **`024707`**, not
`024725`. The controller derives the new word from the UNIQUE
exact type/geometry/owner entry in independently accepted
same-build v1911 physical evidence, then the v1912 physical
trace rechecks both its original foreign-owner2 value and its
new test-only owner3 value before native cleanup.

An earlier discarded v1912/v2 controller incorrectly reused
`024725` after the MM table compacted. Its checkpoint showed
that word was then an inactive/stale owner4 descriptor. That
simulation was terminated and **NOT ACCEPTED**; no production
code, KCORE or historical data was changed. This is a physical
test-harness bug, not a newly diagnosed kernel bug. The valid
v1912/v3 fixes the root cause, never guessing a post-free index.

## Native physical result (all octal)

- From MM10, only the original temporary target owner2 is
  externally corrected to owner3 at MM `024707`, after all
  three v1911 retries and real PI6. No native MM response,
  transition flag or original machine instruction is deposited.
- The original PURE/KCORE recovery reaches the genuine
  `mm_free(PROCESS)` call `033420` and return `033421`, AC1=0;
  the exact `120000..130000` target disappears, **MM10 -> MM9**.
- Original TRANSITION-clear code `033456` runs only after the
  real free; escrow `u[067]=040000120000` clears to zero,
  RAW source `111200..120000` owner3 remains authoritative.
- The saved private executive continuation resumes a second
  FULL. Its original PACKED source `mm_free` return at `036175`
  is AC1=0; source RAW disappears, newly allocated PROCESS
  extent `130000..140000` owner3 remains.
- At original FULL service return `033737`, AC1=0 and slot3
  is RESIDENT (`047017400001`), VMbase `130000`, no TRANSITION,
  and cleared escrow; MM9 and ROOT remain intact.
- The original user emits `w` after its pipe read and enters
  genuine `proc_exit_current=013655` from original slot3.
  Native finalizer then releases its PROCESS/uarea resources,
  and the original PDP-6 physically executes a **normal HALT
  PC=000000**, not a simulator operator stop. Final MM6,
  `proc_high_slot=1`, current slot0, and slot3 descriptor zero;
  no residual slot3 PROCESS/PACKED owner remains.

One strict source-linked positive physical verifier checks the
exact MM table and ROOT, original KCORE return values, recovery
order, user `w`, original slot3 EXIT and native HALT. FOUR targeted
unsafe physical mutations all reject: fake completed owner repair,
false native target-free success, premature transition clearance,
and wrong terminal MM count. The v1911 prefix is also checked
against its separate accepted full positive oracle.

## Reproduction

    cd $HOME/git/daimos-testkit
    export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1912_BUILD=$TMPDIR/pure-brk-pressure-v1614.syLB4i/build
    export V1912_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean
    export V1912_BASELINE_WORK=$TMPDIR/daimos-k05-last-orphan-v1911-physical-v2
    export V1912_WORK=$TMPDIR/daimos-k05-terminal-reconcile-v1912-physical-v3
    make test-pure-k05-terminal-reconcile-physical-v1912
    make test-pure-k05-terminal-reconcile-audit-v1912

The original v1910 source build is reproducible through
`make test-pure-k05-parent-exit-build-v1910`; supply its
actual BUILD directory and accepted source-matched original
PURE probe. The controller checks all completed compressed
TSFS members before running the original PDP-6 simulator.

Accepted SHA256:

- Physical transcript `d4e4c884b00eb61f455587e60cd8d19033dfbcb220160bf21f4584a51045de96`
- Source-linked controller `0ab39813f75552eb623171899ca56b64dbe10d979ce12d40d407da01fec1b26e`
- Original fixed KCORE `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- Original optional PURE `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`

Evidence: `$TMPDIR/daimos-k05-terminal-reconcile-v1912-physical-v3/`.
No production source, fixed RAM, IMAGE, BSS or default policy changes.

**K05 remains OPEN:** this is a physically reconciled *test-induced*
foreign claim. It does **NOT** establish automatic owner repair or
safe forced reclamation when an owner stays permanently unknown.
Additional allocator/PI6/fault cases and broader platform
validation remain. K06-K09 OPEN; RAW PURE/mode3 default OFF.
