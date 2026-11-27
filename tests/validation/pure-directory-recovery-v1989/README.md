# v1989 staged exact directory FULL escrow and rollback

    make test-pure-directory-recovery-v1989 DAIMOS_REPO=/path/to/DAIMOS
    PURE_TEST_COMPILER_V1984=gcc make test-pure-directory-recovery-v1989 DAIMOS_REPO=/path/to/DAIMOS

The existing v1985 test fixture links actual placement, MM, directory
codec, bounded DXR loader and FULL restore. The opt-in stage
DAIMOS_PBM_FULL_ESCROW_V1989 is compiled only for this native test;
installed profile and old runner defaults are unchanged. Explicit
proc_pure_bitmap_recover_v1989 is called on slot zero, not scheduled by
the actual idle reaper. No physical PI6/fault acceptance is claimed.

Host oracle compiles the original source-extracted heap validation,
save/phase/clear helpers, checks 16,777,216 exact round trips (all
16384 lengths x 256 target indices x four phases), cycles source
sectors and legal floor/current shapes, rejects invalid heap/target.
This is arithmetic coverage, not a simultaneous physical allocation
of every possible interval.

Native each PDP6/KA10 and GCC/KCC: 82 actual FULL attempts and 80
explicit recovery calls. Original moved bitmap from production DROP;
second shape independently creates a real larger bitmap with the
original codec, VM04000, floor02000/current02001. The latter is a
controlled grown-VM fixture, not an actual BRK syscall. Both shapes
exercise normal and lost finish reply, real bounded read, no-fit,
source pin refusal, lost allocation and cleanup replies, known
target-unpin/free/source-unpin refusal and false-success replies.
Repeated refusal preserves exact length, target, original heap and
owned pins. Retry without backing mount frees only the provisional
target and owned pins, leaves original mode3 unpinned and unlocks;
normal FULL can retry. Real allocator reuse of previously retired
target is preserved. Invalid target replies poison the field, unknown
pin/finish/codec/identity cases remain HOLD; no deferred commit.
Changed source address/length/owner/pins, missing source/target,
foreign overlapping target/source, changed lifecycle flags/BRK version/
backing/credential and nonzero current slot refuse without MM action.
Changed identity immediately after unpin must prevent target free,
and repairing test metadata cannot reauthorize the HOLD transaction.

Nine executed source mutants per compiler reject:
lose-length, lose-current-brk, retain-authority, no-pair-proof,
no-free-proof, no-source-proof, no-version-tag, no-post-identity,
no-heap-proof. Initial oracle missed no-post-identity; added exact
two-owner post-unpin witness and no subsequent free; final runs reject
at octal036. Earlier test runner generation anchor was ambiguous
(two parts.append calls); fixed fixture generator; no production bug.
No new compiler/assembler defect, existing GCC include-order warning.

Evidence relative TMPDIR:
pure-bitmap-placement-v1985.EUrnBZ (KCC),
pure-bitmap-placement-v1985.UVLe58 (GCC),
pure-full-escrow-size-v1989.5i7fcn (actual DOBJ sizes and comparison),
pure-bitmap-placement-v1985.40pXAR (old placement runner PASS),
pure-full-escrow-regression-v1989.BGuVtC (old full native PREVM runner).
Stage GCC1801->2178 TEXT (+377), KCC2240->2698 (+458), zero DATA/BSS.
Stage OFF directory and RAW-only DOBJ byte-identical to b5a5552d
on both compilers. This is staged leaf accounting, not an installed
package measurement. No new fixed or per-process permanent word.

Remaining: actual idle-service dispatch/arming/backoff integration,
source-built profile and physical FULL failure tests, dirty DROP,
unrecoverable source loss/corruption policy, 48K/real DSH/latency/stack.
The trusted stable u-area and matching backing records are not an
allocation generation or authentication system. Do not recover HOLD
or consume an independently owned pin.
