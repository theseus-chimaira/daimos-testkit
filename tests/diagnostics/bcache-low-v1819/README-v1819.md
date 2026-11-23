# v1819: source-linked LOW BCACHE allocator placement

The historical v1636 testkit worktree carried an unmerged BCACHE
placement assertion and an executable old-HIGH mutation. Production
has already used the `MM_ALLOC_LOW` contract since v1636, and the
historical v1636 physical six-child evidence is already represented by
the committed `pure-cache-low-v1636`, `pure-cache-pressure-v1637` and
`pure-six-matched-v1639` diagnostics.

The existing `daimos-bcache-allocation-v1.s` test was stale: it
required allocation preference 1 (HIGH), making its current production
baseline fail. Its assertion now requires 0 (LOW), without changing
the tests for the 0201-octal-word slab, MM owner 6, or fetch/reclaim.

`run-v1819.sh` extracts the current `bcache_pdp6.s`, requires the
exact LOW argument instruction, and creates one mutation that writes
the old HIGH preference into stack argument 5. The PDP-6 simulator
must accept the source-linked production baseline and reject the
mutation through `__test_exit`, rather than through an assembly or
linker failure.

Run `make test-bcache-low-placement-v1819`. This is a focused
cache-allocator correctness test, not a full physical 48K PURE test.
