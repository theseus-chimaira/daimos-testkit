# P1-C v1579: native snapshot/BACKSTORE interleaving

Date: 2026-11-14. Tested against DAIMOS v1578 production sources.
Scope: source-linked PDP-6 transaction test, not a full physical guest.

The runner extracts the actual `memfs_snapshot_pdp6.s` and
`backstore.s` sources into a disposable `$TMPDIR` workspace. The only
source annotation exports the private `snapshot_span` address to the
native oracle. No production source or runtime binary is modified.

The test uses a 512-sector simulated backing range, one preexisting
process owner at sector zero, and a 4,096-word MEMFS pool. The real
snapshot mount allocates the final 38 sectors (474..511) and preserves
the first owner. During genuine `memfs_snapshot_shutdown` execution,
the test-controlled physical endpoint interleaves an actual 90-sector
`backstore_alloc` after the INVALID commit header, and a further
18-sector allocation while metadata is being written. The production
shutdown then emits the final valid commit header. The native oracle
checks all three write phases, physical range and buffer arguments,
header geometry, every bitmap bit across the full 512-sector extent,
and exact accounting: 147 occupied sectors before temporary release,
39 after. It checks both process releases and that the older process
and committed snapshot remain allocated.

Executed source-linked negative controls:

1. Erase each reserved snapshot bit instead of setting it.
2. Skip the final snapshot commit header.
3. Reverse the allocator's occupied-bit test.

All three produce a failed runtime `__test_exit` oracle. The runner
requires that particular failure, rejecting unrelated assembler/link
errors as acceptable negative results. The unchanged baseline passes.

Run:

```
DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross" \
    sh tests/validation/daimos-p1c-snapshot-interleave-v1579.sh
```

**Limit:** This is one native PDP-6 execution of the real snapshot and
BACKSTORE code with synthetic read/write completion. It has no physical
DSK/DRM DMA, no actual scheduled process swap-in/out, no independent
PI completion, and no natural device failure. The injected allocator
interleavings establish shared bitmap/commit safety in a controlled
sequence, not simultaneous physical HALT and swap I/O. P1-C remains
OPEN for the latter and for mapped DEVICE/VOLUME/PI fault isolation.
