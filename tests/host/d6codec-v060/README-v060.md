# D6 grouped host codec v060 acceptance checkpoint

`run-v060.sh` compiles the candidate host CLI and reusable compressor/decoder
library with C99 warnings as errors. It checks:

- Native v051 `darc.dxr` fixture bit-for-bit (2762 source, 2247 encoded words).
- All 81 DXR corpus payloads against independent Python native-policy output
  and decoding (159973 raw, 131463 compressed words).
- Odd-halfword match distances 1 and 3, including overlapping references.
- Invalid control counts, reserved bits, descriptor padding and token kinds,
  output length mismatch, truncation, trailing input and bounded output.
- Deterministic 10000-word mixed random/zero/repeat round trip and 1000
  compressed-word bit mutations with canary guards around the decode output.

Manual AddressSanitizer/UBSan build of `decode-regress-v060.c` and the library
passed on 2026-10-13. These host tests do not imply native KCORE integration
or automatic wire-format migration. The production D6LZ36 path remains active
until the entire boot, DXR, VFS/PURE/TSFS, KPACK and tool chain is converted.
