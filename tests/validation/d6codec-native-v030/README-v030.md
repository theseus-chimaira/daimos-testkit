# v030 — native PDP-6 step-limit workload bounds

Isolated daimos-testkit measurement based on the accepted 126-word v029/v028
encoder and 99-word decoder, unchanged except for versioned symbols.
The 128-word source fixtures contain either deterministic pseudorandom
36-bit words (distinct-word workload) or 128 identical nonzero words
(highly repetitive workload). Both pass exact native round-trip tests.

Using `p10run --exec-mode step`:

| Fixture | fails at step limit | passes by step limit |
|---|---:|---:|
| distinct-word input | 30000 | 60000 |
| repeated input | 2000 | 5000 |

These are bracketed **end-to-end** execution bounds, not encoder-only retired
instruction counts or PDP-6 cycle counts. The step limit controls simulator
execution up to completion; a failing limit means the test did not finish.
The workload and test harness remain identical per comparison, but the
number of decoded tokens and encoded bytes changes. Native cycles cannot
be inferred directly from this result.

On the original distinct fixture, the first go-mode failure was insufficient
output capacity (64 words). The fixture was corrected to reserve 192 words,
including the control word overhead. The compressor itself was unchanged.

The result establishes that an exhaustive 128-word matcher may spend much
more CPU time on poorly compressible data than on uniform repeated data.
Further work should obtain exact isolated encoder execution counts and
explore early exits for noncompressible regions, without paying excessive
resident RAM. No production DAIMOS/KCORE modifications.
