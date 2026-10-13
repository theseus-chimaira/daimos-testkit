# v033: one-entry lookahead match-result cache

Research-only native PDP-6 experiment, isolated in daimos-testkit. When
literal lookahead finds a valid 128-word-history match, it preserves the
length (AC015) and distance (AC13), sets a register-only valid flag (AC010),
and consumes those values at the next group boundary rather than repeating
the full backward search. The literal output path must not clobber AC010.
No persistent RAM or intermediate token storage is added.

The first implementation failed native fixtures because its cache flag used
AC014, a register clobbered by the match scanner. The corrected version
passes all five native PDP-6 regression tests: ordinary match, hidden
match after literals, grouped literals, zero-run length boundary and
output-capacity rejection.

DAS code sizes: encoder **135** words (baseline 126), decoder 99 words,
combined 234 words (baseline 225); codec .data/.bss both zero.

Encoder-only step-limit bounds on two 128-word workloads:

| Input | baseline v031 | v033 cache |
|---|---|---|
| distinct 36-bit words | fails at 50000, passes by 55000 | same |
| identical nonzero words | fails at 2000, passes by 2500 | passes by 2500 |

The limited step brackets do not demonstrate a sufficient speed improvement
to justify **nine extra resident instructions**. In particular the cache
cannot help most distinct-word lookahead probes, where no usable match
result is found. The v033 candidate is preserved but NOT promoted over
the 126-word baseline. Further detailed profiling would be needed to
quantify its benefit on repetitive-but-mixed workloads. This is neither
a full native even-halfword encoder nor the production kernel interface.

No DAIMOS/KCORE or concurrent shared files modified.
