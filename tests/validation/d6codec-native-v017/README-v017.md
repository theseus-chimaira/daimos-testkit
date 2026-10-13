# v017: PDP-6 structural decoder reduction

Experimental testkit-only decoder for the counted v006 stream, with literal,
paired word-reference and zero-run tokens. No DAIMOS/KCORE modifications.

Native DAS .text word counts: v015 99, v016 98, v017 structural shared
output bounds 94, v017 exhaustive branch-layout search selected 93.
The 93-word candidate passed `p10run` PDP-6 execution of the v015 fixture:
one literal, overlapping three-word distance-1 match, three-word zero run.

`search_v017.py` exhaustively assembles eight combinations of three
independent structural/branch rewrites (two of the four source choices are
no-op and excluded). Actual DAS object word counts are recorded in
`optimizer-results-v017.tsv`; `decode_v017_baseline.s` preserves the 94-word
input and `decode_v017.s` is the simulator-tested 93-word selection.

Limits: no halfword token decoding, no multi-group/malformed-stream suite,
no resumable input, no kernel C ABI, no dynamic instruction counts, and no
native compatible compressor. Do not integrate into production. Code size
is not net KCORE savings until functionality, safety, and integration costs
are verified. Do not remove stream validation for a smaller binary.
