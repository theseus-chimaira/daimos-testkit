# K07 v1945: original physical secondary source loss and recovery

This is a new acceptance candidate, not yet a PASS. It reuses the
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
