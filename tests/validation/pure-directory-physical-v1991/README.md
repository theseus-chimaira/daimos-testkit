# v1991 physical directory FULL rollback and retry

    make test-pure-directory-full-build-v1991 DAIMOS_REPO=/path/to/DAIMOS V1987_BUILD=/path/to/accepted/build
    make test-pure-directory-full-physical-v1991 V1991_BUILD=/path/to/new/build V1991_WORK=/path/to/new/work
    make test-pure-directory-full-audit-v1991 V1991_BUILD=/path/to/new/build V1991_WORK=/path/to/work V1987_BUILD=/path/to/accepted/build

Actual source-built strict swapless 64K PDP6 GCC image with
DAIMOS_PBM_DIRECTORY_V1983=1 and DAIMOS_PBM_IDLE_RECOVER_V1990=1.
Exact original v1987 INIT/COMP/POST DXR bytes, TSFS three members,
55 files,316 extents. Fixed KCORE byte-identical to v1987; linked
PURE MRES identical to accepted v1990 GCC package (5917 words).

At pressure both v1987/v1991 admit all12 children (fixture ceiling,
not maximum): four bitmap251, one RAW3584, seven resident4096;
33 exact nonoverlapping descriptors. Free1789->1332 (-457 exactly
the linked MRES cost), largest APR-aligned interval512 unchanged.
v1991 bitmap bases octal062400,063600,065000,066200. Genuine
foreign TERM on stopped bitmap slots4,5,6 and all10 typed TERM
waits before marked slot3 PIPE continuation.

At actual atomic finish after bounded backing load and verification,
slot3 source062400/251, provisional target160000/4096, both pin1.
Three scoped test-only instruction replacements: actual finish,
initial target unpin, first deferred target unpin. Each changes the
currently stopped leaf entry to JRST fixed kret_neg1, observes the
actual return PC from the live stack and AC1=-1, and restores the
exact original instruction immediately. No injected MM descriptor,
pin, timer, process, scheduler, backing or payload state. This is
controlled leaf refusal, not an actual hardware memory failure.

Actual synchronous refusal -> PAIR -> original fixed armer, then
real idle deadlines ticks21375/21407, delays16->32->64. Exact
original source bytes, entire MM table, original backing/credential,
saved PC, both pins, TRANSITION and BRK escrow retained while held.
Second original recovery retires exact provisional APR, unpins
original bitmap, restores original BRK010000,,010000, clears escrow
and TRANSITION; no READY. Original retry pending cleared before
next real FULL. Subsequent actual atomic finish and EXEC to distinct
unmarked2048-word APR with same slot/u-area, changed backing, no
reservation. All12 exact exit waits, final MM and mode map, normal
HALT at PC0, unchanged root tapes. Independent verifier reuses the
complete original v1987 lifecycle oracle after separately verifying
the delimited fault segment; actual final finish is retained.

Eleven corrupted trace controls reject: wrong refusal opcode,
unrestored instruction, wrong return result, changed source length,
lost source pin, wrong heap, changed source bytes, reset backoff,
stale READY, stale pending and missing HALT. Historical v1987
lifecycle and v1988 physical PREVM audits re-PASS; v1987 eleven
negative traces re-rejected. No production changes or new compiler
or assembler defects. Scope: physical known-pin PAIR rollback only;
FREE/SOURCE/ambiguous ownership are native-tested, not physically
faulted here. 48K, KA10 boot, real DSH, latency/stack, dirty DROP and
irrecoverable source-loss policy remain open.

Evidence relative TMPDIR:
pure-directory-recovery-build-v1991.WDZiGC/build,
pure-directory-recovery-physical-v1991.OxbcV9/physical.clean,
audit-v1991.log; simulator completed in approximately404s.
