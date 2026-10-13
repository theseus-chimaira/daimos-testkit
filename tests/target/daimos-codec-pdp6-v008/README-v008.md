# DAIMOS native PDP-6 compression checkpoint v008

Both experimental entry points are PDP-6 assembler. This checkpoint is a
literal-only subset of the v006 universal stream: it intentionally does not
yet perform compression or decode packed matches. It is **not** an acceptable
replacement for the production D6LZ36 codec.

Assembled with:

    das -F -C -O codec_v008.dobj codec_v008.s
    pdp10-objdump codec_v008.dobj

Result: 59 PDP-6 instruction words total (.text); 28-word literal encoder,
31-word literal decoder. Zero initialized data and zero BSS. This is the
native *subset* footprint, not an estimate for the finished compressor and
universal decoder. The existing production D6LZ36 low-core decoder must be
measured separately before final size comparisons.

ABI (experimental): encoder AC1 input, AC2 source words, AC3 output,
AC4 output capacity, result AC1=encoded word count/-1. Decoder AC1
compressed input, AC2 compressed words, AC3 output, AC4 output words,
result AC1=0/-1. AC0..AC16 clobbered. Caller owns bounds and non-overlap.
These interfaces are not the production kernel ABI.

Outstanding before functional acceptance: simulator-executed roundtrip tests,
malformed descriptor tests, full paired-descriptor decoder, direct match
search and zero-run kernel encoder, allocation-bound proof, streaming input,
and accurate PDP-6 instruction-count benchmarks. The standalone experiment
is deliberately outside KCORE, Stage-1, and all production build graphs.
