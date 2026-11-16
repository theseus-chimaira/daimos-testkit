# PDP-6 P1-E v1615: physical BRK geometry and typed refusal

Status: physical diagnostic, NOT a production acceptance test.
No kernel or standard syscall ABI changes are required.

The v1614 physical pressure experiment used a genuine PURE DXR
but its large BRK failed without a typed refusal or MM owner
snapshot. v1615 introduces a *test-only* monitor-UUO veneer:

    dsys_brk_cause_v1615(logical_break)

It uses the existing BRK UUO and saves the kernel-returned AC2
cause into a guest variable without modifying the shared libc
veneer or production syscall ABI. The guest prints the cause
in octal for nonfatal refusals. A physical out-of-memory
refusal is different: `native_sys_brk` tests AC2 == -1
and immediately calls `proc_fatal_close_current_v879`.
Consequently, the requester cannot execute the veneer
store, error marker or controlled HALT for that case.

An optional SIMH post-HALT dump examines the actual `mm_extents`,
`mm_extent_count`, `mm_arenas`, `mm_arena_count` and current
process slot using the *matching* linked KCORE symbol map.
`analyze-v1615.py` decodes these 36-bit octal words as physical
MM types, owners, sizes, pin counts and aligned gaps. It never
interprets an inactive RAW PACKED suffix as free physical RAM.

## Physically accepted geometry baseline

The 48K no-AUXSTORE TSFS guest using a valid `--pure` DXR
successfully grew BRK from `010000` to `012000` octal.
It then reported `!R`: no mapped process had become
nonresident. A second run grew from `010000` to
`014000`, issued the real HALT syscall before any child
cleanup, and yielded an exact MM snapshot:

* one physical arena `042562..140000`;
* five PROCESS descriptors: parent `052000..066000`
  (size `014000`) and four sleeping children
  `066000..076000`, `076000..106000`,
  `106000..116000` and `116000..126000`;
* zero PACKED descriptors;
* an available gap `046175..052000`, of which exactly
  `02000` words form an APR-aligned contiguous run;
* the separate high free gap `126000..137577`
  is `011577` octal words long.

Thus BRK success at `014000` is **not** evidence of
successful RAW DROP; it used an existing physical gap.
One more in-place APR quantum should consume the lower
aligned gap before any new reclaimed prefix is needed.

## Targeted next physical experiment

`run-steps-v1615.sh` requests `014000`, then `016000`,
then `020000` octal in the same guest. The last request
should cross the in-place-gap boundary. A test-only
`dsys_halt` before terminal cleanup allows the MM table
to be examined only when BRK succeeds or returns a
nonfatal refusal. A fatal OOM reaps the requester,
and a later simulator halt captures post-cleanup MM
state, not the failing allocation's live owners.
Do not claim a successful RAW reclaim until an actual
PACKED extent and mode transition are demonstrated.

With a freshly built test media image:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-brk-refusal-v1615/run-steps-v1615.sh

To replay a preserved image without rebuilding KCORE,
set `PURE_BRK_BUILD_V1615` to the verified build
directory and run `replay-v1615.sh`. The replay copies
TSFS media into its own temporary directory before use.

Both programs are **diagnostics**, not required passing
validation tests: reaching reclaim or producing a typed
error is not proof of MM rollback, completed RUN/WAIT,
immutable source lifetime or net RAM savings. Those
remain separate release gates.

## Stepped 020000 result: requester lost before live MM snapshot

The retained physical 48K trace `pure-brk-pressure-v1614.JWhMvA`
reached `aaaa[B052450/042502]1[1056450/042502]`
`2[2060450/042502]<010000+020000>wwww`, followed by a
simulator HALT at PC zero. There is no `[A...]` BRK
success, no `C...F` nonfatal refusal and no controlled
`H` marker. The children printing `wwww` is consistent
with their pipe reader seeing EOF after the parent
was terminated. This is consistent with the source-defined
fatal OOM path, but does not independently capture AC2.

The MM decoder at that final HALT sees current slot
zero, six DYNAMIC extents and no PROCESS/PACKED owners:
user owners were already cleaned up. That snapshot
must not be used to claim RAW DROP, restoration, gap
geometry at failure or net physical savings. The
earlier controlled `014000` HALT snapshot (slot one,
five PROCESS owners, zero PACKED) remains valid.

Next diagnostic must stop the simulator before the
fatal close path mutates MM state (source-mapped
breakpoint or equivalent monitor observation), then
inspect AC2 and the owner table. Do not alter the
production OOM policy.
