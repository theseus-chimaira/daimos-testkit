# D6 compact descriptor experiment v006

Experimental codec and benchmarks: NOT for production DAIMOS integration.
One universal decoder accepts all streams produced by this experimental
encoder. The encoder invokes a bounded v004-derived match finder (127 word
maximum and 254 halfword maximum) and repacks its token choices. This is
an investigation of descriptor encoding, not an optimized kernel compressor.

## Stream format

Every control word has a 6-bit token count (1..30) and 30 flag positions
(bit 29 is first), with unused flags zero. Following the control word are
ceil(match_count/2) descriptor words, then literal words in token order.
Two 18-bit match descriptors share each descriptor word, first in the left
half and second in the right half; the final unused right descriptor is zero.
A descriptor has two kind bits, seven length bits (1..127 full words),
and nine distance bits. Kinds: 0 word back-reference, 1 zero run, 2 halfword
back-reference; kind 3 is invalid. For halfword references the length is
still in full words, but distance is in 18-bit halfwords (1..511). Odd
distances require halfword reconstruction; even distances use direct word
copies. Distance zero is legal only for zero runs.

The encoded stream needs the expected output word count from its container.
No checksum, version header, or independent length is stored in this stream.

## 81 compiled DAIMOS DXR load images

DXR headers and relocation bitmaps excluded. All three codecs and the v006
candidate round-trip each image exactly. The corpus is the same as v004.
Original 159973 words; production D6LZ36 140835; v004 halfword 135515;
v006 paired descriptors 131548 words. Paired descriptors save 3967 words
against v004, and 9287 against D6LZ36 on this corpus.

## Correctness and limits

600 randomized/patterned round-trip and truncated-stream checks passed under
ASan/UBSan, plus malformed-header checks. The tests do not establish complete
malformed-stream safety, compiler correctness on PDP-6, decoder word counts,
or peak-memory suitability. Encoder size/workspace and decoder resident code
must be measured before contemplating kernel integration. Descriptor placement
in front of group literals requires buffering token metadata when encoding.
The repacker rejects a match longer than 127 words; the research match finder
therefore explicitly caps matches at 127. A production compressor needs
streaming and bounded-space operation, including rollback during eviction.

Production DAIMOS and pdp10-doc remain unchanged pending implementation.
