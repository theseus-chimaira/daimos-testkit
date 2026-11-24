# K05 v1906: escrowed RAW FULL target must not unlock under foreign MM claim

Date: 2026-11-24. **Original 48K PDP-6 native and physical PASS**.
The v1905 versioned test proves that the former v1902 implementation
could unlock TRANSITION when an actually retained provisional PROCESS
target lost its owner identity. v1906 fixes that specific defect
without introducing a permanent KCORE word or new u-area storage.

## Production code and exact information needed

The optional PURE MRES already knows the original full PROCESS
target when an actual failed FULL restore retains two MM owners.
After marking slot-0 retry, the service now escrows this target
physical base in the right half of existing u-area word 067.
Its high-half retry flag is unchanged. The nonresident scheduler
does not interpret that right half as a clock epoch while the owner
is TRANSITION-held. A real 48K failed FULL stores:

    047106: 040000120000  ; existing retry bit, target base 120000

The recovery must verify the escrowed target base and valid
alignment before any native free. If it still owns a complete
temporary PROCESS target, the owner/geometry must match that exact
base, otherwise it is NOT freed. After any native free, the
recovery scans the actual *entire* MM table for any extent
overlapping the original target address range, regardless of
owner or type. Only an absent target and exact sole unpinned
authoritative PACKED RAW source permit u[067] retirement and
TRANSITION clearance. An uncertain foreign owner is never freed.

The existing native PDP-6 KCC service tests PASS the original
pinned-source and target refusal, real target free, lost successful
free reply, duplicate/invalid MM owner, wrong backing and FINALIZE
cases, as well as new missing/wrong escrow, re-tagged foreign
owner and partially overlapping foreign extent refusals. The
historical v1902 native fixture is not rewritten; the v1906
fixture explicitly tightens its previously permissive foreign
target assertion.

## Accepted physical 48K execution

The original five-child compressed TSFS/BRK/PIPE guest first
executes its real native `mm_free(PACKED)` at the compiled return
PC `036175`, returning MM_ERR_BUSY=-5 while the RAW source is
test-pinned. It has both original owner3 RAW `111200..120000`
and complete owner3 PROCESS target `120000..130000`, MM18,
TRANSITION and VMbase0. After removing the source's test pin,
the controller changes only MM target `024725` from owner3
`000001000003` to owner2 `000001000002`. This intentionally
injects corrupt ownership; it is not a legitimate owner transfer.

At THREE independently executed parent user heartbeats, the original
physical MM table still contains 18 extents: source RAW pin0,
foreign-claimed target PROCESS pin0, and original parent/other
owners unaffected. Slot3 TRANSITION and VMbase0 are still held,
its saved private CTX_PC and FDCTL remain identical, and actual
u[067] retains `040000120000`. Original PCLK advances
`024625`, `024725`, `025025` octal, and the existing shared
post-VM backoff remains armed at intervals `0100`, `0200`, `0200`.

The controller then **repairs only its injected MM owner error**
by returning the exact provisional PROCESS descriptor at `024725`
to owner3. This is a test-only operator intervention, not an
automatic recovery of an arbitrary foreign claim. The original
native `mm_free(PROCESS)` at `033420` succeeds with return 0,
MM18 -> MM17. The original transition-clear instruction at
`033456` executes only after the PROCESS target is physically
absent; the escrow is retired. A second original FULL then frees
the PACKED source (return 0 at `036175`), publishes an actual
RESIDENT APR at `120000`, and all five child EXIT/typed WAIT,
parent `Z`, real PDP-6 HALT PC0 PASS. MM8 at Z, MM6 at HALT,
no remaining child owner and original TSFS root unchanged.

The accepted full physical audit rejects all **16** independently
mutated genuine source-built PDP-6 transcripts, including false
foreign injection, premature TRANSITION clear, absent/incorrect
escrow, changed private PC, lost retry clock, false native MM
return, premature APR/parent gate and missing typed WAIT/HALT.

## Exact image/evidence identity

- KCORE DXR SHA256:
  `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- PURE MRES DXR SHA256:
  `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`
- Accepted full original physical trace SHA256:
  `c22a45e4b89602b2edfbe2daa75c4294d7c4ffd828cf5094584e3f5d5832055a`
- Historical reproduced v1905 defect trace SHA256:
  `660ca0198938bc52cb1a4496f00116d78e390e58905e94062b157c074db70ba1`
- Fixed KCORE IMAGE `024167`, BSS `000415` octal: **unchanged**.
- Optional PURE IMAGE `004615` -> `004761` octal (+100 decimal words).
  No new per-process words, process table fields or fixed kernel RAM.

## Reproduction

Run with `DAIMOS_REPO=$HOME/git/DAIMOS`,
`PDP10_PREFIX=$HOME/cross`, `TMPDIR=${TMPDIR:-$HOME/tmp}`:

    make test-pure-k05-foreign-native-v1906

Build a 48K PDP-6 guest from current DAIMOS sources, with the
versioned five-child user gate and original compressed TSFS media:

    V1903_SOURCE_DIR=$TMPDIR/daimos-k05-foreign-target-v1906-source \
      sh tests/validation/pure-k05-full-commit-v1903/build-source-v1903.sh

Set `V1906_BUILD` to the reported `pure-brk-pressure-v1614.*/build`
directory, then prepare its source-linked installed PURE probe:

    V1845_BUILD=$V1906_BUILD \
      V1845_WORK=$TMPDIR/daimos-k05-foreign-target-v1906-probe \
      sh tests/validation/pure-k05-secondary-physical-v1845/probe-v1845.sh
    V1906_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean \
      V1906_PHYSICAL_WORK=$TMPDIR/daimos-k05-foreign-target-v1906-physical \
      make test-pure-k05-foreign-physical-v1906
    V1906_PHYSICAL_WORK=$TMPDIR/daimos-k05-foreign-target-v1906-physical \
      make test-pure-k05-foreign-audit-v1906

Accepted local evidence:
`$TMPDIR/daimos-k05-foreign-target-v1906-physical-v1/`,
native KCC tests:
`$TMPDIR/daimos-k05-foreign-target-v1906-native-v1/`.

**Not closed:** arbitrary permanently foreign-owned allocations,
missing source backing, untrustworthy allocator metadata, terminal
failed-FULL cleanup and all PI6 interruptions. This test proves
safe quarantine while foreign-owned and normal cleanup only after
explicitly repaired test corruption. RAW PURE and mode3 remain
default OFF; K05-K09 remain OPEN.
