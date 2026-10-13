# v021 native bounded-memory encoder/decoder checkpoint

All experiments are confined to daimos-testkit. DAIMOS, production KCORE,
existing kernel ABI, and shared testkit Makefile/TODO are untouched.

The assembler encoder emits the v006-style counted bitmap group layout used
by the v020 even-only native decoder. It currently emits literal groups and
kind-1 zero-run descriptors (first/left 18-bit half). Zero-run length is
limited to 127 words. It writes directly to the caller-provided output
buffer and uses registers only, with **zero intermediate token heap or
scratch buffer**. It does NOT search for word-reference or halfword matches.
It has an experimental AC calling convention and clobbers preserved
registers; kernel C ABI integration is NOT complete.

Native PDP-6 simulator verification:
* `run-v021.sh`: eight zero words followed by three literals; exact
  encoder-to-decoder 11-word round trip: PASS.
* `test_boundary_v021.s`: 127 zeros plus a literal: PASS.
* `test_capacity_v021.s`: capacity one word and an 11-word source returns
  the expected encoder error: PASS.

Assembler measurements (`das -F -C`, `pdp10-objdump -h`): encoder 59
36-bit instruction words, decoder 99, combined 158, no .data or .bss.
The figures exclude callers, stack, VFS source refill and production ABI
adaptation. This is NOT the final compressor footprint. Full match finding,
robust bounds/malformed tests, and a fixed low-core resumable decoder
are outstanding and no production integration is permitted.
