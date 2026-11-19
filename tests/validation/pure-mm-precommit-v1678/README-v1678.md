# v1678: original PDP-6 MM pin/rebase precommit refusal

Status 2026-11-19: **native source-linked preflight PASS** and **paired
48K original physical A/B/C MM precommit-refusal recovery PASS**.
This is a scoped fault recovery gate, not full PI6/fault high-water.

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

## Original physical 48K refusal test (source-linked protocol)

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
still requires the full nine-child RUN/EXIT/WAIT guest. Physical acceptance is established only after both independently
executed GENERAL and STRICT runs, their exact MM/PROC/MEMINFO state
oracles and source-linked negative witness tests have passed.

## 2026-11-19 paired 48K original physical acceptance: scoped PASS

The GENERAL and STRICT 48K source-built systems each booted independently
from actual three-member TSFS, ran nine native PIPE-held PDP-6 children,
refused the tenth RUN under original MM fragmentation, and completed
all nine original EXIT/WAIT paths. Neither source-built fixed KCORE nor
the production MM/scheduler instructions differ from v1674.

**Correct precommit failure result:** the first original MM rebase
call rejects the injected one-word-invalid 0200-sector skip; the
original C DROP removes its pin and retains child **slot 2** as an
intact, sleeping, unpinned RESIDENT owner. The other eight children
become actual unpinned RAW PACKED owners; this differs deliberately
from v1674's nine PACKED children and is NOT an oracle relaxation.
At B the original MM owner/mode/process-table/u-area parser proves
8 PACKED + 1 RESIDENT, with slot 2's TRANSITION flag cleared and
all others' RAW suffix length exactly `VM_WORDS - 128`. Native
SYS_MEMINFO totals/allocated resident process words match the same
original physical MM contents at A/B/C.

| 48K original physical MM | GENERAL | STRICT |
| --- | ---: | ---: |
| Free A -> B -> C | 27323 -> 2548 -> 27323 | 27323 -> 2548 -> 27323 |
| Largest free A -> B -> C | 27323 -> 1523 -> 27323 | 27323 -> 1523 -> 27323 |
| Original MM live extents A / B / C | 9 / 26 / 9 | 9 / 26 / 9 |
| PACKED children at B | 8 | 8 |
| Fully RESIDENT failed child at B | slot 2 | slot 2 |
| Original physical pin changes or leaks | None | None |
| Exact live MM descriptors restored at C | PASS | PASS |
| Native EXIT/WAIT/PID1 completion | PASS | PASS |
| Actual MM rebase refusal counter | 1 | 1 |

At B, the actual original permanent KCORE service trampoline at
physical octal `023401` contains its relocated JRST
`254000032065`. The v1678 verifier uses this original instruction
and the source-linked PURE MRES map to find the relocated *test-only*
`v1678_rebase_fault_count` at physical octal `035533`: value
`000000000001` in BOTH independent guests. The test counter advances
only on a genuine `MM_ERR_INVAL` from original PDP-6
`mm_pure_rebase_pinned_v1381` assembler. The native v1678 MM pin
and precommit-refusal tests and two executed unsafe source mutants
remain PASS.

Original physical A/B/C signed reports are byte-for-byte identical
across GENERAL and STRICT (SHA256):
`ef48a65af796f55e8601e3957d6d5d7f028c2f82d758c4503724075d0f9fd291`.
Fixed KCORE SHA256, byte-identical to accepted v1674:
`66296e13440e1f4db3bf263e181dc33e085f55dc4b0f07c09f147e6c1c88b506`.
Test-only injected PURE MRES SHA256, identical in both:
`d1df7423d2b8698cb71b1edd53452eec2b1eb93666c63e4f112f52c6fae01e01`.

Both independently replayed original MM/PROC/SYS_MEMINFO sources
reject five actual A/B/C source tamperings: a retained TRANSITION
bit on the failed resident child, a corrupt PACKED descriptor span,
a forged PACKED pin, a corrupted C descriptor which fails precise
recovery, and a forged native SYS_MEMINFO process word count.
Three additional source-linked relocated PURE MRES witness mutations
are rejected: the lost fault counter, invalid installed JRST and
forged duplicate physical count. None is accepted merely for
producing syntactically valid JSON. The negative suite checks the
positive original trace exactly reproduces the signed result first.

**Limits:** this is one real MM precommit geometry refusal with
ordinary cleanup and later process EXIT/WAIT, not arbitrary persistent
faults, physical PI6 in-instruction interleavings, dynamic backing
loss, terminal quarantining, KA10 or a continuous original-MM
write-watch high-water. The v1674 normal-workload minimum 1255 free
words cannot be reused as a v1678 fault-injected minimum. Full
P1-E and eventual mainline/all-branch integration remain OPEN.
