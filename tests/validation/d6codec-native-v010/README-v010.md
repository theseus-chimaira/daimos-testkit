# Native PDP-6 codec simulator regression v010 (KNOWN FAILURE)

The test runs only via `run-v010.sh`, using `p10run` in isolated deposit
mode. It does not build KCORE, boot DAIMOS, or modify either DAIMOS checkout.
Inputs: 8 zero words followed by 3 nonzero words, and a 64-word output buffer.
Expected: exact round-trip from native assembler encoder through a copied
fixed-low-core v009 decoder, with zero return status.

Current result: FAIL. The test returns `__test_exit=1`, indicating the
v009 assembler encoder returns a negative value on this simple fixture.
This failure is an actual simulator result; prior assembler success was
insufficient evidence. Production integration remains blocked. A correct
fix to the encoder and repeat of native simulation are prerequisites before
adding paired halfword descriptors. The test is opt-in and not wired into
the suite's passing CI targets while this known defect is being investigated.

The fixture installs a private copy of `decompressor_v009.inc` at fixed
address 000060 *inside the simulated PDP-6 only*. It does not change
DAIMOS's production fixed-address decoder or KCORE.
