# v009: native PDP-6 incremental codec experiment

This is an isolated low-core decoder experiment based directly on DAIMOS's
`system/stand/pdp6/common/decompressor.inc`, with an assembler encoder.
Not linked into KCORE or Stage-1; no production stream changes.

## Assembled footprint (DAS -F -C)

- Production fixed resumable D6LZ36 decoder: 40 text words.
- Experimental fixed resumable decoder with zero-run token: 56 text words.
- Experimental assembler literal/zero-run encoder: 56 text words.

The decoder preserves the existing resumable AC state and return status.
It adds zero runs with bit 15 set in an otherwise D6LZ36 match descriptor,
with bits 7..14 and 16..35 zero and run length minus one in bits 0..6.
Original word-match tokens remain unchanged. The encoder is intentionally
simple: it groups up to 30 literals, or emits a single zero-run match token
for runs of 1..128 zero words. It does not yet emit word back-references,
paired 18-bit descriptors, or halfword references; it is not the v006 format.
The assembler encoder also currently uses a research-specific caller ABI,
not the public kernel C ABI. It must receive a standard ABI wrapper prior
to production use.

These object assembly results prove syntax and section size only. They do
NOT prove execution or bounds safety. Need native simulator tests on source
buffers, resumable refill behavior, exact stream length checks, and encoder
output cross-validation before accepting even this extension. The next step
should move to v006 compact descriptors using the existing decoder's fixed
address and established kernel-facing buffer/VFS interfaces.
