# D6 codec staged encoder geometry regression v1354

This native PDP-6 fixture verifies that the staged grouped encoder
rejects source and destination pointers or extents outside physical
18-bit word-address space, and refuses overlapping nonempty buffers
before reserving or writing a compressed group header. It also checks
zero-capacity rejection for nonempty input, valid empty output for zero
input, and a normal one-word literal encoding with source preservation.

Run with:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-encode-bounds-v1354/run-v1354.sh
```

The suite passes on the v1354 hardened staged encoder. The unchanged
v1353 encoder fails its source-overflow witness with code 1. The
existing v055 full-DXR native ABI/roundtrip fixture also passes.

This milestone does not enable the grouped codec in a production image.
An encoder max-output sizing contract, host-format parity, all boot
loaders and kernel consumers, and stack/physical-RAM acceptance remain
separate integration gates.
