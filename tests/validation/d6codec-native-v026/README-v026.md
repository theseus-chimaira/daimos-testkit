# v026: PDP-6 native bounded 128-word candidate matcher

This opt-in daimos-testkit experiment replaces the v024 distance-one
word-reference search with a backward scan of up to 128 source words.
A candidate is extended up to 127 output words. The longest match of
length at least three is emitted using the v006 counted-group descriptor
layout. The encoder writes directly to the supplied output buffer and
uses no intermediate token heap or static scratch buffer.

The v026 native encoder assembles to **123 36-bit instruction words**;
the unchanged even-halfword-only decoder is **99 words**, so combined
code is **222 words**, with zero assembler data/BSS. The v024 encoder
was 110 words. This is NOT proof of better net RAM.

The simulator fixture forces a 4-word match at backward word distance 5,
asserts its packed descriptor `04005,,0` at the expected stream offset,
and compares every decoded word to the source. It passes on PDP-6.

Important: The inherited literal grouping heuristic still only tests
for *distance-one* repeats during lookahead. Consequently longer-distance
matches inside a long literal group may be missed; this remains a
prototype rather than a competitive universal compressor. A native
instruction-count benchmark and search-effort cap are still needed before
choosing a production matcher. The kernel ABI and resumable VFS input
are likewise unimplemented. DAIMOS/KCORE are untouched.
