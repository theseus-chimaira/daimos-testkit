# v1993 directory dirty DROP recovery

    make test-pure-directory-dirty-drop-v1993 DAIMOS_REPO=/path/to/DAIMOS
    PURE_TEST_COMPILER_V1984=gcc make test-pure-directory-dirty-drop-v1993 DAIMOS_REPO=/path/to/DAIMOS
    make test-pure-directory-dirty-package-v1993 DAIMOS_REPO=/path/to/DAIMOS

The native fixture extends the existing v1985/v1990 source-linked
runner. Compile the actual DROP and service with
DAIMOS_PBM_DIRTY_DROP_V1993, real MM, codec, placement, RAW/PURE
restore, and original idle armer, deadline, scan and backoff.
The outer idle interrupt handoff remains a controlled fixture.
Test-only wrapper for a partial prefix store returns WRITE_FAULT;
ordinary placement refusals and lost rebase/unpin replies use
the original MM leaves or explicitly scoped refusal wrappers.

Each GCC/KCC and PDP6/KA10 executes 25 counted DROP calls,
including real pressure/reclaim (additional call), healthy marked
directory, no-gain RAW, legacy RAW recovery, partial prefix write,
failed placement, repeated REBASE/UNPIN refusal, lost replies and
actual idle retry. Check the original RAW bytes, exact descriptor
and pin, saved backing, original APR size and credential, BRK,
storage map, transition, retry epoch/delay and independent pending
scheduler cursor. No new pin or backing access during retry,
including an absent mount and a wake to SRUN. Changed source size,
owner, pins, saved backing, provider/mount credential and even
coherently changed VM/MM length must not authorize another MM
operation. Repairing the test metadata does not rearm HOLD.
Post-MM identity change prevents publication or transition unlock.
Both malformed commands and foreign current slots refuse.

Six executed unsafe variants per compiler reject: dirty-unlock,
no-retry-route, no-rebase-proof, no-unpin-proof, no-post-proof,
forget-saved-identity. A provisional single-bit dirty marker
collided with a FULL SOURCE tag when mode2 was inconsistent:
the new native regression failed at octal040. Final two-bit
marker 0600000 excludes every legal FULL phase and candidate
count. Final native matrix passes on both CPUs and compilers.
v1990 KCC OFF regression passes original 82 FULL,80 recovery,
127 service/deadline cases and all eight mutants.
Existing GCC include-order warning and KCC unused historical
fixture notes, no new compiler/assembler defect demonstrated.

The package runner builds the actual strict experimental directory
+ idle profile with dirty DROP OFF/ON/OFF/ON in one unique build
directory per compiler. It verifies repeatable package bytes/map,
unchanged fixed KCORE, no dirty recovery export in OFF/fixed,
and invalid mode/refused missing idle prerequisites. This is
linked-package evidence, not physical boot/interrupt/latency
qualification. Default OFF. No claim of recoverability for arbitrary
physical memory corruption outside the bounded disjoint codec writes.
Physical dirty DROP and ambiguous ownership qualification remain open.

Final native evidence relative TMPDIR:
pure-bitmap-placement-v1985.kXbsn1 (GCC),
pure-bitmap-placement-v1985.KOjzbR (KCC),
pure-bitmap-placement-v1985.2qseo5 (v1990 OFF KCC regression).
Provisional collision failure: pure-bitmap-placement-v1985.AqGoY4.
