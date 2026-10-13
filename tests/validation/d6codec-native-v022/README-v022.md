# v022 — bounded distance-one word matching, PDP-6 simulator

Experiment stays entirely in daimos-testkit. No KCORE, DAIMOS, or common
build changes. Based on v021 with a bounded word-reference candidate at
word distance one (length 3..127). The encoder writes directly to the
caller-supplied output, uses registers only, and allocates no intermediate
heap or static token buffer. It is NOT a full 1..511-distance match finder.

`run-v022.sh` passes in the PDP-6 simulator. Test input: eight identical
nonzero words followed by three other nonzero words (11 source words).
The test asserts both the exact round-trip and a ten-word encoded stream:
two words for one literal, two for one distance-one word reference of seven
words, and six for three trailing singleton literals. This forces actual
word-reference emission, not merely a literal-only round trip.

The deliberately conservative literal grouping emits singleton groups,
so this prototype can recognize the next word-reference opportunity. This
is inefficient in both size and speed for mixed data. The next iteration
must replace this with a bounded grouping/lookahead policy, avoiding large
intermediate token buffers. A complete distance search and aligned
halfword matcher are still missing.

No production C ABI, resumable refill, robust corruption suite, or final
resident-cost accounting has been implemented. Production integration is
not authorized by this test.
