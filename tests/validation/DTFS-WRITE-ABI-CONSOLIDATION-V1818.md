# DTFS raw write ABI consolidation v1818

The detached v206 write test checks a durable invariant: a physical
DTFS write must pass its UNIT, BLOCK and BUFFER arguments intact to
the DTC dispatch routine even if intervening operations overwrite
PDP-6 accumulators 1 through 3.

The old v206 fixture expects `bcache_reclaim` in the write path. That
is no longer the production contract. The current DTFS code first
calls `dtfs_intent_mount_gate_v1561`, restores all three arguments from
the private stack, and calls `bcache_invalidate_all`, a cache leaf
which deliberately uses AC4 rather than AC1..AC3. The write must not
reintroduce memory reclamation at this point.

`daimos-dtfs-write-preserve-v1818.sh` extracts **actual source** for
both production routines, with a hard failure if expected ABI anchors
disappear. Its PDP-6 assembly fixture substitutes only the physical
write sink, mount-intent gate, error-marker path, and kernel returns.
The gate deliberately overwrites AC1..AC3 before the production
veneer restores them. The sink verifies exact unit 3, block 0144
and the original data buffer pointer.

The simulator verifies a production baseline and rejects two
mutations via the guest's explicit nonzero exit value:

1. Replace write-time `bcache_invalidate_all` with the destructive
   `bcache_reclaim` stub from the historical v206 fixture.
2. Alter the actual invalidation routine to corrupt AC2.

Run with `make test-dtfs-write-abi-v1818` or set `DAIMOS_REPO` and
`PDP10_PREFIX` and invoke the shell runner directly. This is a
source-linked *focused unit simulation*; it is neither a real tape
write nor an end-to-end DTFS mount, cache, or recovery test. No DAIMOS
kernel source was changed to accommodate the fixture.
