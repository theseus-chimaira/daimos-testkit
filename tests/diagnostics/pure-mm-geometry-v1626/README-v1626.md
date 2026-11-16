# P1-E v1626: physical MM capacity and fragmentation proof

The actual v1625 sixth RUN was refused by the original loader when
`vm_space_create` returned `EXEC_LOAD_NOMEM`. The v1625 physical
breakpoint examined every authoritative MM descriptor at the original
`proc_run_claimed_bad` PC `017725`, BEFORE failed-child cleanup.

Run the source- and executable-matched audit against the saved
physical 48K witness:

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_GEOMETRY_BUILD_V1626=/path/to/six-child/build \
    PURE_GEOMETRY_TRACE_V1626=/path/to/v1625/trace.clean \
    PURE_GEOMETRY_IMAGE_V1626=/path/to/six-child/user/init.dxr \
        sh tests/diagnostics/pure-mm-geometry-v1626/run-audit-v1626.sh

The source-linked output is in octal PDP-6 words:

    arena                        042562..140000
    MM extents                   022
    PACKED suffixes             5 * 007000 = 043000
    total physical free gaps     016173
    largest 02000-aligned gap    007000
    original PURE image          001043
    BSS                          004001
    user origin + stack          002020
    initial VM request           007064
    APR-aligned image            010000

The five PACKED extents remain MM-owned physical RAM; the five
omitted immutable `001000`-word prefixes are separate free holes.
Free words spread across gaps cannot be combined to create one
initial `010000`-word APR extent at this snapshot. The sixth RUN
is not refused for lack of process-table slots (high=010, slots=014).
The testkit rejects a corrupted owner and an overlapping extent.

This is a proof of the *captured* physical allocation geometry,
not proof that all future compaction/reclaim policies must fail.
No production kernel/MM/source layout modification follows from
this expected capacity limit. 48K's five-child parent BRK request
still lacks a successful completion and all final WAIT statuses.
Full P1-E lifecycle and positive physical net/peak RAM remain OPEN.

## Independent 64K experiment

The v1614 physical guest builder now accepts the opt-in
`PURE_PHYS_KWORDS_V1626=64`, paired with BOOT_CORE_WORDS 0200000,
while leaving its historical 48K default unchanged. Run the
unaltered six-child PIPE/WAIT diagnostic, with the v1624 source-
distinguished RUN/SLEEP error markers, on 64K as follows:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-mm-geometry-v1626/run-64k-v1626.sh

This is a second actual SIMH/TSFS/no-AUX build, not a projection of
48K MM geometry. `run-v1614.sh` retains its original strict pressure
criterion: a normal failure/`!R` is useful negative evidence but
is NOT accepted P1-E lifecycle/peak RAM. Keep the unique build and
user DXR evidence for later replay and source-matched MM inspection.
