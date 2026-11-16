# v1614: real PURE 48K PDP-6 BRK pressure diagnostic

This is a reproducible **non-accepting** full guest
experiment. Do not include it in the passing validation
suite until the exact physical MM owner state, PI6
restoration and PIPE/WAIT status are verified.

Builds a PDP-6 48K lowmem GCC three-member TSFS root.
No DSK/DRM backing media are attached. The optional
PURE MRES is enabled explicitly, not by changing the
production default. A self-contained C89 test INIT
creates four sleeping processes and attempts a parent
BRK allocation while their writable sentinels remain
live. Tests actual stored process and wait interfaces.

Crucially the test builds the current DAIMOS host
`dlink.c` from SOURCE, uses `dlink --pure`, and
rejects any output lacking `dxrcheck -d purity=PURE`.
The old v1613 diagnostic accidentally used a non-PURE
DXR (`purity=UNKNOWN`) and was not a valid reclaim
acceptance workload.

The first genuine PURE DXR on 48K:

    aaaa[B052450/042502]<010000+024000>!Gwwww

The octal pair is guest MEMINFO mapped-process words
and resident core, *not* physical MM extent accounting.
SIMH breakpoints in the same physical guest showed:

    proc_swap_reclaim:            2 calls
    proc_pure_ram_drop_v1381:     4 entries
    mm_pure_rebase_pinned_v1381:  4 entries

Those are entry counts, not proof that MM publication
completed successfully. The parent BRK returned a
failure, so the guest intentionally did NOT publish
the success/restore/WAIT witness.

With the same 48K image, disabling the unused DSK
controller changed the resident-core snapshot from
octal `042502` to `042157`, but BRK still failed.
A second source-linked PURE DXR with a lower parent
BRK target `022000` also reached `!G` and did not
complete the run. These are both negative diagnostics.

The failure could arise from exact contiguous-memory
geometry, inability to move retained PACKED suffixes,
or a real MM/BRK/restore error. The trace currently
does NOT distinguish these cases. Do not change the
kernel until the MM extent layout and refusal code
are proven.

Run the experiment:

    DAIMOS_REPO=/path/to/DAIMOS KEEP_TEST=1 \
        sh tests/diagnostics/pure-brk-pressure-v1614/run-v1614.sh

Expect **failure** until a source-backed MM analysis
and revised physical acceptance are complete. The
runner preserves its test directory and console
on failures. No P1-E release gate is closed here.
