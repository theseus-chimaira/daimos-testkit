# v052 — KCORE replacement ABI prototype, single new codec

The new counted-control / paired-descriptor format MUST **replace** D6LZ36.
There is no compatibility mode, legacy decoder, dual-format auto-detection,
or permanent coexistence. Both 129-word encoder and 99-word decoder are
mandatory in KCORE. This version stages only a tested ABI prototype in
`daimos-testkit` to avoid interfering with concurrent production KCORE work.

The PDP-6 assembler wrapper preserves AC10..AC15, matching the documented
existing kernel decoder adapter's callee-saved register contract. Its entry
AC1..AC4 retain the experimental whole-buffer calling convention; AC17 is
the stack pointer. Tested on a complete 2,762-word darc DXR: compressed
length, each encoded word, decompressed output, and all six saved ACs
PASS. Wrapper text 22 words, zero data/BSS. Measured baseline 129+99+22 =
250 36-bit text words before final ABI checking, address validation,
stack footprint and optimizations. The tested assembly convention is NOT
yet verified against compiler-generated C call sites.

## Atomic format cutover required

A successful production replacement requires the following to switch in
one coordinated build, with no lingering D6LZ36 producer/consumer pair:

1. `system/stand/pdp6/common/decompressor.inc` fixed-low-core Stage-1
   decompressor and Stage-1 call conventions for DSK/DRM/DTC/MTC/PTR;
   the new decoder's API is not the old resumable-core API.
2. `system/kernel/core/d6lz_pdp6.s` VFS/direct-buffer entry points, its
   refill/state handling and KCORE's fixed decoder object construction.
   User of the decoder must not retain the old stream format.
3. EXEC loader, PURE backing loader and TSFS restart decoder call sites,
   plus process swap references as applicable. Validate all input/output
   framing and bounded consumption.
4. Host and userland format producers: tools/host d6lz-codec, boot image
   compressor, DXR producer, TSFS pack/check and any build/install scripts.
   All artifacts must be rebuilt; old compressed artifacts are incompatible.
5. Replace temporary identity `kpack_codec_v1.c` with tested real
   compression/decompression wiring when its packed-process lifecycle is
   ready. Do not activate incomplete PACKED scheduler transitions.
6. Boot smoke tests across device loaders, KCORE link/size, DXR execution,
   TSFS, packed state transitions and regression testkit runs.

DAIMOS `PROJECT-STATE.MD` currently explicitly warns against premature
production codec integration. Do not bypass the remaining transactional
packed-process tests or make a half-switched boot image. This file is a
versioned testkit design, NOT the canonical pdp10-doc specification.

## Still blocking production merge

Measure wrapper-inclusive stack high-water, check 18-bit address
wraparound/nonoverlap and bounds, validate compiler-generated register
calling and error return, then implement atomic producer/consumer cutover
in a separate integration worktree. Sharing code between encoder and
decoder is deferred until AFTER successful production integration.
