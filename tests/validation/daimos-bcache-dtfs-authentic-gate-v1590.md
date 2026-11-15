# v1590: repair v1490 BCACHE/DTC fixture against current DTFS write gate

Date: 2026-11-15. The original v1490 native cache regression could
no longer link after the DTFS write veneer acquired the production
`dtfs_intent_mount_gate_v1561` dependency. Removing the call or
returning an unconditional success would bypass the DTFS V2 media
identity and write-protection policy, and is not permissible.

The repaired v1490 fixture still compiles the original production
BCACHE and DTC read/write veneer. It additionally links all original
production DTFS write-gate components from the kernel source tree:
v1561 mounted owner gate, v1553 first-write, v1552 owned MM scratch,
v1550 marker validation, v1551 arm, v1554 verify and v1566 clean.
It initializes a genuine V1 published mount root with provider 5,
public mount ID 1 and physical Type-551 unit 2. The initialized
root/media records belong in `.data`, not zero-initialized `.bss`;
the initial diagnostic experiment proved that a nonzero source
initializer in BSS cannot be trusted as actual published state.
Existing hardware DTC and MM implementations remain explicit native
fixture test doubles, as before; the V2-only MM pin/unpin test doubles
fail closed. No DTFS security gate is stubbed, dropped or modified.

Acceptance re-executes original v1490 physical DTC register and cache
invalidation checks and both unsafe mutation controls. New native
checks also verify that an unpublished root and a published V2 owner
without the mandatory retained MM scratch cannot authorize physical
DATA/DIR WRITE. The V1 gate intentionally admits legacy units with
no matching V2 owner, so the test does not incorrectly treat that
legacy behavior as a defect.

Run result:

```
PASS v1490: DTC write retains raw unit/block/buffer and invalidates cache
PASS v1490: refused MM free leaves slab owned but no stale valid tags
PASS v1490: old reclaim-before-write corruption rejected
PASS v1490: stale-cache-on-refused-free mutation rejected
```

The independent `daimos-dtfs-intent-mount-v1561.sh` also passes all
35 original PDP-6 mounted intent/owner cases and rejects all 13
deliberately unsafe mutations, including inappropriate V2 admission,
wrong mount owner/identity/physical selector and failed physical I/O.

This repairs **only the legacy test harness**. No installed DAIMOS
kernel source, RAM, ABI or disk format changes. P1-C remains OPEN for
live cache retention when no reclaim is needed, mixed-provider
recoverable faults, concurrent ownership and repeated-load stability.

Reproduce:

```
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
export TMPDIR=${TMPDIR:-$HOME/tmp}
sh tests/validation/daimos-bcache-reclaim-io-v1490.sh
sh tests/validation/daimos-dtfs-intent-mount-v1561.sh
```
