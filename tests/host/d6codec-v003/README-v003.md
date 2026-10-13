# D6 codec candidates v003: 36-bit control bitmap

Experimental host implementation only. No production integration or format promise.

The control word contains 36 flags; each flag governs one following 36-bit word.
Zero flag: raw literal. One flag: descriptor, with bits 35..34 selecting
word back-reference (0), zero run (1), halfword back-reference (2), or
reserved (3). Bits 33..18 contain the run length, bits 17..0 the distance.
Halfword lengths are counted in 18-bit symbols, must be even, and copy into
an even-numbered output-halfword boundary. Distance may be odd, allowing
matches starting at the opposite half of a preceding word.

The host reference encoder tests 128 preceding words and, optionally, 256
preceding halfwords; it searches exhaustively and is not appropriate as a
kernel encoder. The decoder writes directly into a caller-provided output
buffer and uses no separately allocated history. The decoder is presently
word-oriented; the 18-bit operations incur per-halfword shifts and masks.

Build and test:

    cc -std=c99 -O2 -Wall -Wextra -Werror codec_v003.c test_v003.c -o test_v003
    ./test_v003

This fixture suite is synthetic. Benchmark against production D6LZ36 on real
36-bit process images before choosing a format. Its codec is NOT backward
compatible with production D6LZ36 and has no on-disk header or checksums.
Kernel integration and persistent documentation intentionally deferred.
