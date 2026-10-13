# v023 bounded literal lookahead — testkit only

This PDP-6 native research encoder replaces the v022 singleton literal policy
with a bounded scan of at most 30 consecutive literals. It stops before a
zero word or a distance-one word repetition verified to span three words.
Literal tokens are still grouped separately from match descriptors; the
existing no-heap, no-token-buffer emission strategy is preserved.

Simulator PASS fixtures:
* test_v023.s: 11 source words, 8 compressed words (v022: 10),
  byte-for-byte 36-bit word round trip;
* test_literals_v023.s: 11 distinct literal words, one 12-word group;
* test_boundary_v023.s: 127 zeros followed by a literal;
* test_capacity_v023.s: insufficient output capacity rejected.

DAS .text: 122 words encoder, 99 words decoder, 221 combined, zero static
.data/.bss in the codec objects. v022 encoder was 96 words. This improves
literal grouping but grows code by 26 words; it is not yet a net RAM win.

Important limitations: only distance-one word references, no aligned
halfword match search, not the kernel calling convention, no resumable
input, no error rollback of output on full capacity, and no broad fuzzing.
No DAIMOS/KCORE or shared testkit configuration files were modified.
