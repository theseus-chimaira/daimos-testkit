# v024 word-distance distribution, original v006 compressor

`profile-v024.c` is a host C99 tool that runs the unchanged v006 research
encoder over the exact 81 DXR files listed in `results-v006.tsv`, excludes
DXR image headers and relocation maps, and parses v006 paired match tokens.
The match-token distance distribution is in `results-v024.txt`.

In 159973 input words, v006 uses 6054 word match tokens, of which only
9 use distance one. Remaining word-reference tokens mostly cover distances
9..128. Halfword match tokens are counted separately. This is a property
of the original v006 encoder/token choices, not a lower bound or optimum
for a new native encoder. In particular, even halfword matches overlap
with the possible usefulness of alternative word match choices.

A native distance-1-only matcher is consequently not a realistic stand-in
for final compression performance. Wider searches should be measured for
encoder instruction words, search CPU cycles, and compressed output savings.
DAIMOS production and concurrent KCORE work remain untouched.
