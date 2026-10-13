# v049 — largest-DXR full native stress regression

`dsh.dxr` is the largest DXR in the established 81-image v006 manifest:
15,870 36-bit payload words. The self-contained assembler fixture is
generated using the v046 independent host policy model. The native v045
encoder emits exactly 12,723 36-bit words, word-for-word identical to the
host reference, and the native decoder reproduces all 15,870 source words.
PASS using the PDP-6 simulator in normal `go` execution mode.

This large native stress fixture exercises many control-group and match
boundaries in one execution and checks the actual full stream rather than
only a header or sampled windows. Compression saves 3,147 36-bit words,
19.83% on this input. The experiment does NOT establish exact PDP-6
instruction/cycle counts, maximum call-stack consumption, malformed-pointer
safety, bounded resumable output, or production loader ABI.

The CRT allocates a 512-word stack region; its presence by itself is NOT a
stack high-water measurement. A future v050 ABI/stack investigation must
measure actual high-water use and preserve register calling conventions.
The producer/consumer code is still test-only; DAIMOS/KCORE untouched.
