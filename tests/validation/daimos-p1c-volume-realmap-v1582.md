# P1-C v1582: native real BLOCKSET mapper and BACKSTORE gate

Date: 2026-11-15. Scoped source-linked native PDP-6 acceptance of the
real multi-member VOLUME mapper and fixed critical BACKSTORE bridge.
This is **not** the full physical multi-member/VOLUME controller gate.

## Real production source under test

The runner `daimos-p1c-volume-realmap-v1582.sh` extracts unchanged
production `blockset_direct_configure..blockset_tail_blocks` source
from `system/kernel/fs/fs_mres.s`, the complete real compact
`system/kernel/storage/blockset_dispatch.s` and the production
reason-specific critical terminal dispatch from
`system/kernel/proc/proc_storage_runtime_v30.s`. The native test
installs the real `blockset_map_block` service into the real
`blockset_runtime_service_call` jump just as MINIT would.

Only the descriptor contents and last-mile DSK270/DRM236 controller
completions are test-controlled. The actual BSET MRES descriptor has
three INTERLEAVE members, each with 0200 filesystem sectors followed
by 0100 BACKSTORE sectors; the collective filesystem occupies 0600
logical sectors. Members are units 1, 2 and 3 with bases 0100,
0200 and 0300 octal. The first six actual BACKSTORE sectors must
map to (unit, physical block):

```
1 0300
2 0400
3 0500
1 0301
2 0401
3 0501
```

The native physical-controller completion fixture checks the unit,
physical block, DSK/DRM selection and read/write direction on every
transfer. It never supplies an alternate mapper. Each successful READ
also writes a distinct marker through the actual 0200-word buffer
stride. The real critical HALT is located by the native linker's
symbol table rather than by a hard-coded PC.

## Executed results

All 13 baseline cases PASS on `p10run --machine pdp6 --mode deposit`:

- DSK three-block READ and six-block WRITE; DRM three-block READ and
  six-block WRITE, all verifying exact interleaved physical mapping.
- DSK second-sector failure and DRM third-sector failure both reach
  the **real BACKSTORE-specific** fatal HALT rather than the ROOT
  reason, with the correct number of physical transfers and owned
  blocks unchanged.
- Disabled new backing with live owned blocks still HALTs critically;
  disabled and unowned backing returns -1 without a false HALT.
- Missing mapped VOLUME service with active backing HALTs without
  accessing the wrong physical sector; the same inactive/unowned
  service failure returns -1 without fatal classification.
- Range-overflow, out-of-range start and zero-length transfer return
  without touching physical storage.

Eight actual executed production-source mutants are all REJECTED:
incorrect physical block, wrong member unit, missing filesystem-data
offset, misrouted DRM controller, skipped critical HALT, bypassed
mapper refusal, ignored owned blocks when allocations are disabled,
and incorrect per-sector buffer stride (0200 replaced by 0100 words).

One fatal example linked `kcore_critical_media_swap_halt_v1515` at
octal PC `001342` and the simulator halted at precisely `001342`.
The observed fatal case retained `0300` octal owned backing blocks,
counted exactly three physical DRUM transfers and zero mismatches.

## Boundaries

This test links the actual scheduler-independent mapper and shared
critical BACKSTORE gateway, but its physical completion is a fixture,
not Type-270/Type-236 hardware PI. No live multi-member filesystem,
full guest, independent swap-in while snapshot DMA is active, or
real mapped-volume controller fault is established by v1582.

The entire test lives in `daimos-testkit`, creates unique versioned
scratch paths in `$TMPDIR`, and changes no DAIMOS production source,
RAM footprint, ABI or persistent disk format.

Reproduction:

```
DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross" \
    sh tests/validation/daimos-p1c-volume-realmap-v1582.sh
```
