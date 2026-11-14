# DTFS v1559: write-path source coverage regression

Date: 2026-11-14. P0-B **OPEN**. This is a source-level
regression gate for future physical DTVOL2 DIRTY-before-data
integration, **not** a native guest or durable-write acceptance.

## Finding

The existing native DTFS C and assembly write sites currently
converge on the common `dtfs_dtc_write` veneer:

- `dtfs.c`: three C calls for block/metadata writes.
- `dtfs_runtime.s`: one internal native/foreign create write.
- `dtfs_chain_walk.s`: one chain-data write.
- `dtfs_resize.s`: four resize/data/metadata writes.

The central veneer itself invokes raw `dtfs_dtc_write_jump`
only after its physical-unit DTVOL2 guard. The separate
`dtfs_intent_arm_v1551.s` deliberately uses raw physical RBN0
WRITE to avoid recursive entry into the future intent gate.
These are **11 recognized source callsites**, including the
two intentional raw calls. The v1559 script checks this source
boundary and requires the V2 refusal branch to remain present.

## Automated regression

Run from daimos-testkit:

```
python3 tests/validation/daimos-dtfs-write-path-coverage-v1559.py \
    "$HOME/git/DAIMOS"
```

Result: **11 source callsites PASS; five unsafe source mutations
rejected**. The mutants replace the chain walker and resize
calls with direct raw writes, bypass the central V2 guard,
reverse its refusal branch, and recursively call the ordinary
data veneer from the RBN0 intent marker service. The script
mutates only temporary copies and does not touch source files.

## Scope and limitations

This is deliberately narrow: it covers direct `pushj 17` calls
to the two DTFS assembly symbols in `dtfs*.s`, and explicit
`dtfs_dtc_write(...)` calls in `dtfs.c`. It does **not** prove
absence of indirect controller writes, non-DTFS callers,
unrecognized new APIs, DMA transfer completeness, exclusive
provider lease, media replacement safety, or correctness of
the future writable V2 transaction. It does not enable V2
writes and must not be used to close P0-B. The full production
write gate must still be source-linked and tested with real
PDP-6 physical I/O and sleeping owner checks.
