# P1-E v1627: physical six-child lifecycle separate from RAM benefit

The genuine v1626 64K TSFS/no-AUX PURE diagnostic admitted all six
children and completed parent BRK `010000 -> 017000` and later six
`w` markers. Its original v1614 test asserted that RAW drops must
occur specifically between the before- and after-BRK MEMINFO samples.
The observed identical `010000`-word logical growth correctly
triggered `!R`, so the parent exited before WAIT. This is a valid
negative result for *timing of additional reclamation*, not a
complete parent/child lifecycle test.

v1627 generates a distinct real 64K guest from the unchanged v1614
C source. It changes only the number of children to 6, the BRK
target to 017000, splits the parent RUN/SLEEP refusal, and replaces
the too-specific *additional* BRK reclaim assertion with a bounded
accounting check that process words did not grow more than the BRK
APR increment. The new `L` marker means lifecycle-only, NOT positive
RAM savings. The original child's PIPE read, both writable data
sentinels, 057-octal EXIT status, and the parent's exact six
`dsys_wait` status checks and terminal `Z` remain untouched.

Run the physically source-built test:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-lifecycle-v1627/run-v1627.sh

The opt-in `PURE_LIFECYCLE_ONLY_V1627=1` acceptance in the normal
v1614 runner is used only with this explicitly generated source.
Without the flag, v1614's original stronger reclaim assertion and
normal acceptance are unchanged. The compiler, kernel, MM and
PURE MRES remain unmodified.

After a real completed simulator guest, validate the saved complete
trace and matching guest source/DXR/TSFS manifest:

    PURE_LIFECYCLE_BUILD_V1627=/path/to/run/build \
    PURE_LIFECYCLE_TRACE_V1627=/path/to/run/console.clean \
        sh tests/diagnostics/pure-lifecycle-v1627/run-audit-v1627.sh

Only after verifying the actual `Z`, original source logic and full
WAIT statuses may this be called a physical end-to-end lifecycle
PASS. No claim about peak/net physical RAM or simultaneous RAW
occupancy follows from this test alone.
