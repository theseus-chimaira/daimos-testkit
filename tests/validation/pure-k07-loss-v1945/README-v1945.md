# K07 v1945: original physical secondary source loss and recovery

**v1946 correction:** the v1945 missing-medium rollback, retained
suffix and original-medium return are genuine, but its claimed
foreign-medium restore is NOT established. SIMH clearing and rearming
the same current-PC breakpoint repeats the stop without execution;
the earlier MISSING and FOREIGN_0 share PC034453 and clock6300.
The independent tiny monitor probe in pure-k08-pi6-v1946 reproduces
this behavior. The old foreign checkpoint is withdrawn. The corrected
controller advances to a distinct original PI6 boundary before
rearming restore returns, and its independent verifier requires the
actual 0100-tick service cooldown. The archived v1945 trace is now
deliberately rejected for foreign-media acceptance.

Status 2026-11-26: physical PASS on the current v1939 production
source. This scoped K07 acceptance reuses the
uninstrumented v1942 production GCC lowmem KCORE/KINIT/PURE images and
an independently verified genuine CLEAN DTVOL2 reel seeded by the v1944
guest. No monitor deposits, kernel hooks, synthetic MM owners, or media
writes by the verifier. The new parent mounts the real secondary RO and
uses the exact v1942 plain child and exact v1944 compressed child. The
former is on the TSFS root, the latter is on physical DTC3. The parent
admits children until a checked refusal (4..6 successes), checks sleeping
states and no-growth BRK, closes the pipe, checks every exact PID/EXITED/
status WAIT and parent data sentinel, and finally retires the secondary.

The monitor verifies that slot 3 has a real unpinned PACKED owner before
arming a source-derived FULL breakpoint. The first FULL is required to
be that secondary child. While its original source and separate target
are pinned, the actual DTC3 drive is detached. The actual return must
be -4, the target retired, and the exact unpinned RAW suffix unchanged.
A separate DTVOL2 reel, formatted with the original mkdtfs utility and a
fresh ID, is then attached. Real PREFIX/FULL retry must return -4, retaining
the same complete suffix. The original CLEAN reel is reattached. The
normal guest must complete its exact WAITs, final UNMOUNT, Z and HALT 0.

The independent verifier checks linked/installed service addresses,
physical volume IDs, original provider/backing/escrow, exact word contents,
MM ownership and final media integrity. A different-ID empty native reel
is a real foreign-volume rejection case, not a same-ID clone or an
identical directory/payload substitution. It does not demonstrate all
other storage controllers or arbitrary physical exchanges.

## Reproduction

From daimos-testkit, supply existing accepted builds and the genuine
completed v1944 seed run (not the interrupted DIRTY seed):

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export V1945_BASE=<v1942 five-child build>
    export V1945_SEED_BUILD=<v1943 completed seed build>
    export V1945_SEED_TRACE=<v1944 genuine guest-seeded reel evidence>
    sh tests/validation/pure-k07-loss-v1945/prepare-v1945.sh
    V1945_BUILD=<printed build path> make test-pure-k07-loss-v1945

The scripts leave evidence in a unique TMPDIR directory. A failed or
interrupted run must not be counted as completed source-loss acceptance.
RAW PURE and mode3 remain OFF by default. No K07 closure is implied by
successful image construction alone.

## Accepted physical result

Actual v1945 guest: Iaaaaax[B, unchanged B/A MM18, one root
plain child restored before the secondary FULL. Slot3 original
PACKED 113600..120000, separate PROCESS 122000..130000, both
pin1 at FULL PC040756, opcode 200000000004. Original stable u-area
051274, backing 037141000000, capacity06000. The actual FULL call
returns at 034453 with -4 on removal and on foreign volume insertion.
MM17 both times: exact original PACKED extent pin0, no target,
original backing and provider retained, escrow zero. Media 300003
(READ_SUSPECT), unchanged original identity 262433006735:163245455724.
All 2176 words of the physical suffix are byte-for-byte identical
at FULL, MISSING and FOREIGN_0; SHA256 of 8-byte little-endian
word representation:

a1468bb00db336b10ec727ae2c25245665b45316584a2aee7212786219b219c6

Original reel return permits all five exact WAITs (one earlier w,
four following recovery). Z: MM8, no child VM/u-area/reservation,
root0, media0100003 (ordinary retired healthy tag), one HALT PC000000
and simulator exit0. Clock B=5659, FULL/faults=6300, Z=8548 decimal.
The actual fault returns were sampled at the same clock tick; this is
not K08 interrupt-during-rollback coverage. The original and foreign
reels are both byte-identical to the inputs. The independent verifier
PASSes, and 12 changed actual transcripts are rejected. These are
verifier controls, not twelve executed guest faults.

Evidence: $TMPDIR/pure-k07-loss-physical-v1945.3AsKpm/physical.clean
SHA256 c2c9d9d516fca6b0089279b3e50ce2e38df99269b8692292cb5716da9c8b57ac.
Build: $TMPDIR/pure-k07-loss-v1945.OLgxdN/build.
KCORE SHA256 4177db78eabee2b54a1cb3d6e2cec3eee6e4b0b2d9e330a22f3d6acf052c85e1.
PURE SHA256 e488f1a93315ff7039326c948d1e9b39632507850c999fffa1285f975c6b0c41.
KINIT SHA256 0dd50179f40bfef8880e93071e50293230e85ed7b262e3b7fdb74d9958003843.
No production image or RAM growth. Scope excludes same-ID clones,
undetected swap-and-return between proofs, whole-guest D6FS/TSFS
exchange matrices, K08/K09 and KA10.
