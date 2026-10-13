# v047 — first complete DXR native PDP-6 parity tests

Three **complete**, not sliced, DXR payloads are pinned as assembler data.
`generate-v047.py` extracts little-endian 8-byte-stored 36-bit words from
DAIMOS DXR binaries listed in the established v006 corpus manifest. It
computes expected stream words independently using the v046 v045-policy
host encoder and verifies their full lossless decode before emitting the
self-contained PDP-6 fixtures. Reproduction of native tests requires no
DAIMOS build or external source files once the fixture is generated.

| Executable | Raw words | Native compressed words | Native parity | Native decode |
|---|---:|---:|---|---|
| configctl.dxr | 1769 | 1497 | PASS | PASS |
| darc.dxr | 2762 | 2247 | PASS | PASS |
| d6lz.dxr | 1653 | 1430 | PASS | PASS |

For each, the native 129-word v045-family encoder produces the exact
host-model control, descriptor, and literal words; its output length is
checked and the 99-word native decoder reconstructs every original word.
All three tests passed using the PDP-6 simulator.

Current complete-DXR native verification: 3 of 81 corpus binaries. A
complete 81-image native run is NOT yet established. The aggregate 131463
word total remains a host-model projection. In particular, very large
DXR images may require segmented simulator fixtures or a streaming ABI.

This code is still research-only, not production ABI compatible. Stack
bounds, corruption rejection, streaming state, malformed input fuzz and
integration into KCORE/boot/TSFS/swap remain open. No edits to DAIMOS,
KCORE or concurrent shared testkit files were made.
