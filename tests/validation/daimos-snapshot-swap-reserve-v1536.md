# KCORE v1536: snapshot BACKSTORE reservation and native process ownership

Date: 2026-11-13. Feature correctness, testkit-only. No KCORE
or MRES production modifications.

## Run

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
sh tests/validation/daimos-snapshot-swap-reserve-v1536.sh
```

The runner creates a private version-specific workspace. Set
`V1536_KEEP=1` to retain every linked source, native PDP-6
object, execution log and intentionally unsafe mutation.

## KINIT source-linked C tests

The host compiles **the actual** `proc_swap_boot.c`, using
small, well-defined stubs only for MM allocation, block-header
reading, BCACHE invalidation and zero fill. The internal
boot-time reservation function is unmodified. Across nine
independent initializations, it verifies committed v1/v2,
unsupported version, malformed magic/ranges and failed read,
asserting exact authoritative bitmap bits and accounted
backing blocks. A valid 145-sector backing device with a
38-sector snapshot ending at sector 144 must reserve
exactly sectors 107..144. Boot must publish only one swap
record/MM extent and refuse repeated initialization.

The four executed deliberately unsafe source mutations are
drop v2, wrong end-of-range comparison, missing BCACHE
invalidating read preflight, and missing bitmap ownership.
All four are rejected by runtime assertions (not compiler
failures).

## Actual native PDP-6 BACKSTORE allocator/free

The same runner extracts original current-source assembly
`backstore_alloc`, `backstore_verify_allocated_v795`,
and `backstore_free`; it neither reproduces their
algorithm in C nor assumes host allocator behavior.
`p10run --machine pdp6` executes a 145-sector, five-word
bitmap test. A persisted snapshot owns 107..144 and an
existing process owns block 0. A 107-sector allocation
refuses; an unauthorized free crossing the first snapshot
block refuses; a temporary process allocates 100 sectors
starting at 1, another 6 sectors starting at 101, and
further allocation refuses. Both process allocations
are freed exactly once, the snapshot remains owned,
and duplicate free refuses.

All three native unsafe mutations reject: ignoring a
bitmap occupancy bit, losing used-block accounting,
and omitting complete-run verification. The initial
fixture only freed valid owners and failed to detect
the last mutant. That fixture was strengthened with
invalid and duplicate frees; the final positive test
and all three negative controls now pass.

## Independent cold-reboot corroboration

The existing `daimos-memfs-snapshot-reboot-v1477.sh`
was also rebuilt and run from the current DAIMOS tree
at **128K**. Both complete full-PDP-6 boots PASS:
boot 1 creates and commits MEMFS data/XIP, boot 2
recovers exact data and executes the saved XIP;
both HALT. AUXSTORE geometry remains unchanged.
The prior v1484/1485 multidimensional acceptance
remains historical and was not rerun in full.

These source/native checks and the two-boot regression
are complementary but not one concurrent guest:
actual simultaneous process swap with a MEMFS snapshot
commit and a DTC/DRM/DSK device error is **still open**.
No production data structure, RAM, ABI or on-media
format was added. VERSION 0.5; 32K/optimization HOLD.
