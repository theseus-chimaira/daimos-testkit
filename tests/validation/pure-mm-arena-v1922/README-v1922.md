# Native managed-arena ownership proof, v1922

Run against the current DAIMOS source with the installed native tools:

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-mm-arena-v1922

The gate executes the shared arena/table proof and the original MM
rebase, PREFIX claim, release and commit instructions on the PDP-6.
It uses the established v1384 controlled process, MM allocation,
pin/free, PI and loader fixtures. Arena geometry is explicit, not an
implicit assumption that every 18-bit address is backed by RAM.

18 physical-range cases cover zero/oversized/negative arena counts,
nonempty sorted arenas, trailing invalid arenas, gaps, installed-core
limits, an exact 256K endpoint and address overflow. Twelve table
cases cover cached containing-arena reuse, transitions between three
arenas, holes, crossings, malformed spans, ordering, extent count and
capacity, and valid/invalid empty tables. Seven native mutation cases
verify that DROP and PREFIX claim/release/commit refuse malformed or
unmanaged geometry without changing the original descriptor or data.
A valid retained suffix whose original prefix is unavailable returns
fragmentation rather than invalid geometry.

Five private unsafe assembly variants fail guest assertions at 0101,
01021, 01021, 01051 and 02024 octal. Only actual guest assertion
failures are accepted. The v1612 service gate additionally refuses
malformed arena metadata before compaction, with and without live
extents. The v1920 terminal gate now includes four arena refusal
cases, including absence of the escrowed range in unmanaged core.

Older native fixtures explicitly supply their managed arenas. The
v1381 top-address case models 256K, the v1855 independent bystander
lies inside managed memory, and terminal-only guests link the shared
original MM assembly. Historical v1920/v1921 geometry mutants bypass
the consolidated proof in the relevant caller rather than the removed
local check; their original assertion oracles remain unchanged.

This closes the K06 ownership implementation audit, not arbitrary MM
memory corruption protection, actual PI6 interruption coverage, or
production acceptance. The normal allocator and compactor retain their
existing serialization and valid-table contract. RAW PURE and mode3
remain opt-in.
