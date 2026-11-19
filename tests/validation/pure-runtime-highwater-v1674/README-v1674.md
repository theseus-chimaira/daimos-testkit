# v1674 physical PDP-6 runtime MM write-watch high-water

**Status: experimental; physical positive gate pending.** This testkit-only
extension follows the accepted v1673 RAW PURE 48K pressure test and must
not be presented as accepted until the general and strict variants and
the v1674 negative tests pass.

## Why a new measurement is needed

The v1673 CTY checkpoints A/B/C prove stable original physical MM state
before RUN, after nine owners are packed, and after EXIT/WAIT. They do
not observe allocation spikes between checkpoints. Sampling SIMH at user
virtual-PC addresses is unsafe because those addresses alias KCORE PCs.

This experiment uses SIMH **physical memory write** breakpoints (`-W`),
not execution breakpoints. The host arms watches after PID1 pauses at A
on the original `mm_extent_count`, all 64 original MM extent-descriptor
words for the 48K capacity of 32, and six fixed arena/core descriptor
words. Each modified physical address is recorded with its new value.
All 71 watches are verified with `show -C -W break`. They are disarmed
while the guest holds at C. Neither the kernel nor the guest test
program has any new instrumentation.

`trace-v1674.py` starts with the physically read A descriptor table,
replays **every** watched store in source order, and requires the
reconstructed table to equal the independently examined original MM
at both B and C. Count writes are the atomic insert/delete commits;
they must always leave a valid extent table. In-place extent size edits
are source-qualified by the original MM shrink/grow instruction ranges
and are likewise validated as commits. Every other descriptor write
(shift or metadata update) is replayed but NOT counted as an allocation
sample, even when a partly shifted table happens to look geometrically
valid. This avoids reporting a non-committed intermediate copy as a
real memory high-water.

This establishes high-water among the captured valid MM states after
every original physical descriptor write, not the transient consumption
of an allocator's CPU registers or a non-MM subsystem. In particular,
SIMH stop-and-examine affects host elapsed time; this is **not** a
performance benchmark or an instruction-by-instruction execution trace.

## Execute

    DAIMOS_REPO=/path/to/DAIMOS-development \
      make test-pure-runtime-highwater-v1674

The source is the unmerged PURE development branch with mode3 off.
The v1673 runner builds isolated three-member TSFS test media and
executes the original general+strict 48K nine-child pressure test,
including its accepted negative checks. The v1674 runner substitutes
only its SIMH host controller, then replays each source-linked console,
compares the two high-water reports and executes its own four negative
mutations (missing watch registration, corrupted original write value,
missing original write event, and forged peak summary).

For debugging only, set `V1674_ONLY_VARIANT=general` or `strict` and
`V1673_ONLY_VARIANT` to the same selection. Existing source-built
v1673 images may be reused through `V1673_FIXTURE_BUILD`,
`V1673_GENERAL_BUILD` and `V1673_STRICT_BUILD`, but the original root
manifest must match the supplied fixture path. This diagnostic option
skips the paired profile comparison and **does not close acceptance**.
Set `KEEP_TEST=1` to retain disposable evidence; `V1673_TIMEOUT` is
the host wall-time timeout for each physical CTY checkpoint.

## Gates not covered

No post-user continuous memory result is accepted until the full new
physical trace passes. If it does pass, scope is original MM descriptor
mutation high-water on 48K TSFS/PURE only. Separate gates remain for
root=auto/DSK/DRM, mode3, PI6 fault injection, KA10 and full 32K boot.
