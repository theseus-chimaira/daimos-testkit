# D6 compression investigation v005: match descriptor distribution

This instrument profiles v004 compressed tokens for compiled DAIMOS DXR
load images. Run against all uncompressed DXR files in the compiled image
corpus; the profiler retains v004 exact round-trip checks.

On 81 DXR load images (2026-10-13 snapshot):

- Word reference descriptors: 6054
- Zero-run descriptors: 2
- Halfword reference descriptors: 5411
- Halfword matches with even offsets: 5407 (99.93% of halfword matches)
- Halfword matches with odd offsets: 4
- Halfword matches with length <= 8 halfwords: 5410 (99.98%)

The halfword candidates deliver 5320 fewer encoded 36-bit words compared
with production D6LZ36 on this corpus. A new **paired short-descriptor**
format should be evaluated before any kernel change: two 18-bit descriptors
might share a 36-bit word, but literal ordering and control-token state must
remain unambiguous and decoding overhead must be measured. These statistics
are observations of a greedy 128-word/256-halfword encoder, NOT theoretical
frequencies or an estimate of general process state.

Further work: enumerate halfword match lengths and offsets, prototype a compact
format, evaluate direct 36-bit copies for even distances, measure PDP-6 decoder
code/instruction cost, and add malformed-stream validation. No production
source or persistent pdp10-doc documentation was changed.
