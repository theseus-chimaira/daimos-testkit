# v1630: original 48K physical prefix claim and commit

The v1629 48K PDP-6 TSFS/no-AUX PURE guest proved five actual
PACKED suffixes and complete child PIPE/WAIT/EXIT. It did not
identify which restore branch was selected. The original linked
PURE MRES has v1384 in-place prefix claim and v1391 full-APR
relocation. These must not be assumed equivalent.

This testkit-only physical debugger runs the SAME compiled
v1629 executable, TSFS manifest, KCORE, PURE MRES and private
copies of the Type-551 root tapes. It verifies the exact PURE
MRES symbol offsets and original instruction bytes before using
SIMH read-only debugger breakpoints. It does not patch the guest
or modify production code.

    PURE_RESTORE_BUILD_V1630=/path/to/v1629/build \
        sh tests/diagnostics/pure-restore-path-v1630/replay-v1630.sh

The first original restored owner (slot 2) reaches:

* PC 034610, `mm_pure_claim_prefix_v1384`, physical suffix
  117000, slot 2, omitted PURE 001000, full APR 010000.
* PC 034614, `mm_pure_commit_prefix_v1384`, original APR base
  116000, slot 2, omitted PURE 001000, full APR 010000.

No `proc_pure_ram_restore_v1391` PC 034236 is observed before
the first commit. The original prefix source was successfully
read and the claim reached commit before any fallback. After
breakpoint removal the original five-child guest finishes its
five PIPE/data/EXIT checks, the parent's WAIT/Z and HALT.

Verify physical opcode/source/map/AC identity and unsafe negative
mutation rejection:

    PURE_RESTORE_BUILD_V1630=/path/to/v1629/build \
    PURE_RESTORE_TRACE_V1630=/path/to/replay/trace.clean \
        sh tests/diagnostics/pure-restore-path-v1630/run-audit-v1630.sh

The v1395/v1397 native MM failure-isolation and v1612 native RAW
service regressions also pass on this current source (their
existing compilers may emit unrelated historical unused-test
notes). They do NOT count as a physical full-APR fallback witness.

This accepts the first restored child's genuine in-place claim-
to-commit branch. It does not yet prove every other child's path,
full fallback, fail-atomic source loss, or whole-system net/peak RAM.
