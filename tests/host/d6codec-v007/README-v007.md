# DAIMOS codec v007: first compressor footprint accounting

Measurements use x86-64 host GCC `-Os -ffunction-sections -fdata-sections`
and `nm -S --size-sort` for individual function sizes. These are **not** PDP-6
word counts, nor linked resident sizes. Calls to malloc/free and runtime
helpers are not charged to these figures. See `size-host-v007.tsv`.

Current v006 encoder has two distinct stages: the v004-derived source
match finder produces a full 36-bit descriptor stream, then v006 repacks it
into paired 18-bit descriptors. The host encoder paths alone total 1378
bytes, excluding a 31-byte halfword helper. Eliminating the intermediate
stream should reduce transient RAM use and remove duplicated token handling.
The research implementation currently allocates an intermediate compressed
stream plus final output; that is inappropriate for memory-pressure eviction.

The v006 decoder is 743 host text bytes, compared to 272 for production
D6LZ36, so decoder footprint also needs attention before integration.

Attempting to compile these host uint64_t-based sources with installed
`pdp10-dec-none-gcc` fails because its standalone invocation does not locate
target `stdint.h` and other target runtime headers. More importantly, the
host's 64-bit container representation must be adapted to native 36-bit
PDP-6 words before valid PDP-6 size comparisons. Treat this as a separate
native port; do not compare host bytes to target word counts.

Next: implement a direct bounded-memory encoder with one output stream,
then compare native PDP-6 encoder and decoder code sizes against existing
kernel codec, while measuring actual live-kernel impact and instruction cost.
