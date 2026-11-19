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
