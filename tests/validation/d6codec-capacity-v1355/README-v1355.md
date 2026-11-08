# v1355 native PDP-6 staged grouped-codec output bound

Run with `DAIMOS_REPO=/path/to/DAIMOS sh
tests/validation/d6codec-capacity-v1355/run-v1355.sh`.

The staged encoder's optional allocation-free entry
`d6codec_v053_max_encoded_words` takes the input word count in AC1 and
returns a safe encoded output capacity in AC1, or a full-word -1 for
an invalid count or a bound exceeding 18-bit physical address space.
It clobbers AC0, AC2 and AC3, and uses no stack or static storage.

For N input words the safe bound is zero if N=0, otherwise
`N + ceil(N/30)`. Every nonfinal group has 30 tokens; every token
consumes at least one input word; a group with L literals and M match
tokens occupies `1 + L + ceil(M/2)` output words. As
`ceil(M/2) <= M`, payload storage does not exceed the input words
consumed. Consequently group overhead cannot exceed `ceil(N/30)`.
This is a conservative maximum, not an exact compressed size.

Native cases cover helper N=0, 1, 30, 31; the maximum legal
calculated bound (octal input 0757367, output 01000000), the next
input count (0757370) which must fail, negative and over-18-bit
counts, plus an all-maximum-count rejection.

Encoder cases cover:

- Thirty different literal words: capacity 30 fails, capacity 31
  succeeds; exact roundtrip confirms the input.
- Thirty-one different literal words: capacity 32 fails, capacity 33
  succeeds; exact roundtrip confirms the input.
- One zero word: capacity one fails, capacity two succeeds and the
  decoder restores zero.

The short-capacity tests check a sentinel immediately beyond the
declared output region. Encoder failure can modify an output prefix;
callers must not publish that buffer on error.

This does not claim production KCORE linkage, buffer allocation,
stack-high-water bounds, host/native producer parity or boot cutover.
The currently installed D6LZ36 boot and runtime ABI remain unchanged.
