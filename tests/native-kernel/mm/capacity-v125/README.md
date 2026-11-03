# PDP-6 MM boot-capacity control regression v125

Run with `DAIMOS_REPO=/path/to/DAIMOS sh run-v125.sh`.

Includes the existing 32-entry descriptor pressure and 31->32->31
capacity boundary tests from v122, then selects a 31-entry active ceiling
and confirms that another no-reclaim insertion returns
`MM_ERR_DESCRIPTORS`, preserving the descriptor count and the caller's
output. The backing array intentionally remains 32 entries in this stage.

This regression exercises the production PDP-6 MM code in the emulator.
Boot-time descriptor backing placement and KINIT selection require separate
tests before their implementation is accepted.

Consolidation v1030 (2026-11-03): the synthetic core ceiling is now
256K words; the test focuses on the 31/32 descriptor count boundary
and does not constitute a 32K boot or memory-pressure acceptance test.
