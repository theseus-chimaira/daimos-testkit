# v1678: original PDP-6 MM pin/rebase precommit refusal

Status 2026-11-19: **native source-linked preflight PASS** (not yet
accepted full physical PI6/48K fault pressure).

Unlike the v1677 lost-success return *after* a committed zero-copy PURE
DROP, v1678 exercises genuine original MM refusal *before* a DROP can
commit, with two separate original physical process MM descriptors.

- Case 1: test-controlled `mm_pin_fault_v1678` passes physical base 0
  to the original `mm_pin`, receiving its actual invalid-base refusal.
  The affected source was never pinned or changed.
- Case 2: `mm_pure_rebase_fault_v1678` calls the ORIGINAL PDP-6
  `mm_pure_rebase_pinned_v1381` with one extra PURE prefix word after
  the actual source is pinned. That original assembler's 0200-sector
  alignment guard refuses without changing either physical MM word.
  The original C DROP must execute its cleanup `mm_unpin(source)`.

In both cases the original process remains exactly RESIDENT, all its
text/suffix words are unchanged, pin count returns to zero, PI disable
and restore counts match and TRANSITION is clear; the healthy first
process has a correct PACKED owner and can restore independently.
A later normal reclaim/drop/restore of the previously refused second
process passes using the original PDP-6 MM assembler, C PURE MRES
service, prefix loader, and process state publication.

This test extends only the test fixture prefix-provider adapter to
recognize the second source/u-area. The original owner, state, mode,
rebase and restore logic is unchanged. Source-based native corruption
mutants are compiled and **executed** with the same v1678 oracle:
removing the cleanup unpin is rejected with native guest exit
`000000001201`, and retaining TRANSITION after a clean resident
refusal is rejected with native guest exit `000000001101`.
The original v1654 FULL and v1612 service baselines also run.

Run: `DAIMOS_REPO=<PURE-development-checkout> sh run-v1678.sh`.
This is a native two-owner failure/retry test; it is NOT evidence of
physical nine-owner 48K PI6 fault interleavings, arbitrary MM failures,
source invalidation or repeated unrecoverable owner faults. The
production code and KCORE footprint have not changed.

## Original physical 48K refusal test (in progress, not yet accepted)

The versioned `build-physical-v1678.sh` copies the original DAIMOS PURE
worktree into isolated `$V1678_BASE/source-copy-v1678` (excluding its
`.git` link), replaces *only* the copied PURE DROP source, and builds
GENERAL/STRICT low-memory TSFS images using the same v1674 nine-child
PIPE fixture. Fixed KCORE must match the original v1674 control SHA256.
The test-only DROP calls the **original** `mm_pure_rebase_pinned_v1381`
with a one-word-invalid sector skip only once, after the original
`mm_pin`. It increments the optional PURE MRES word
`v1678_rebase_fault_count` only if the **actual assembler** refuses
with `MM_ERR_INVAL`; thereafter all rebase requests are unchanged.
Original C DROP must perform its cleanup `mm_unpin` and leave the
complete resident process undamaged and retryable.

`run-physical-fault-v1678.sh` uses the actual original 48K CTY A/B/C
MM/PROC/SYS_MEMINFO verifier and test-controlled PI6 process pressure.
The source-linked physical witness recovers the installed MRES base
from the actual KCORE `proc_swap_reclaim` JRST, reads the relocated
fault counter at B, and requires exactly one rejection. Three executed
corruptions of this exact physical witness must fail. `V1678_FAST=1`
omits the expensive continuous 71-write-watch high-water replay but
still requires the full nine-child RUN/EXIT/WAIT guest. The physical
acceptance status must be recorded only after actual successful paired
GENERAL and STRICT runs; until then this section is a test plan.
