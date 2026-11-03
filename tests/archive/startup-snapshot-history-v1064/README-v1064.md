# Historical KCORE startup/swap test branch (2026-11-03, v1064)

Source branch: `test-daimos-startup-snapshot-v72-20261020`, last commit
`68b9169`. Its entire original history is retained as ancestry of
testkit main. The history-only merge does not activate old tests.

## Recovered current test fixes

The v101 source-graph check found a real incremental build defect in
the outer DAIMOS boot Makefile. Current main now tracks four missing
inputs to its generated swap assembly. The recovered, opt-in test is
`test-daimos-kcore-swap-input-deps-v1063`: it passes on the corrected
tree and fails against the original four missing dependencies.

The native FILE fixture historically allocated extra storage for the
mount-extension word at `file_table+041` octal. Current testkit still
used only the 16 two-word file records, risking out-of-bounds access.
The v1064 test now reserves two extra records, initializes the whole
fixture and passes the standalone PDP-6 FILE target regression without
compiler warnings. Neither fix modifies KCORE runtime code.

## Tests not reactivated

The historical startup-snapshot v72 target requires
`proc_startup_snapshot_v72.c`, which is not in current DAIMOS. Its
process/u-area and MRES lifetime assumptions cannot be silently
restored. The historical SYSINFO v98-v99 and single-mapped-pointer
v97 scripts build images with an optional `SYSINFO_MRES_ENABLED` mode
that is absent from current boot configuration.

The old FILE device-word test patches `*_jump` entry symbols; current
FILE assembly instead uses `*_call` service sites. Wholesale test
replay would therefore reintroduce obsolete ABI assumptions. The
historical 48K MonitorFS swapped-live and early DSH/TSFS fixtures
likewise need requalification against current boot/media layout.
These are not current acceptance tests.

## Current checks performed during consolidation

The current `test-daimos-vfs-parent-ac3-v1037` native PDP-6 test
passes. The current `test-daimos-monitorfs-compiler-v1033` passes
both selected compiler configurations, retaining the smaller GCC
MonitorFS reader. The native FILE test also passes. No 32K-specific
test or new KCORE optimization was performed.

Inspect the original branch using `git show 68b9169:<path>` (or a
parent commit) when revisiting a particular experiment. Historical
source and test output are retained for diagnosis, not current gates.
