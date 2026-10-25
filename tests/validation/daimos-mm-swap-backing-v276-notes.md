# v276 live backing-store breakpoint diagnostic

On the 256K PDP-6 24K-BSS eight-pressure-child fixture, SIMH
`backstore_write` entry breakpoint examined these octal values:

* `backstore_blocks` at 024504: `000000004000` (2048 blocks).
* `backstore_blocks_used` at 024505: `000000000320` (208 blocks).
* `blockset_direct_tail` at 024716: `000000002000` (1024 blocks).

The backing allocator thus advertises more blocks than the current
configured direct-tail span. This inconsistency is confirmed but its
causality for this particular failed write is not: no write return
code nor write-start offset was captured. `backstore_write` was entered,
rollback invoked `backstore_free`, and the guest still emitted `p7!W`.
Investigate ownership of direct-tail configuration between AUXSTORE,
BLOCKSET and D6FS before changing production code or capacities.
