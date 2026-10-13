# v013 native PDP-6 encoder fallthrough fix

This is an opt-in testkit-only checkpoint. Neither DAIMOS nor KCORE was
modified. `run-v010.sh` invokes p10run with a three-word nonzero input and
checks that the assembler emits exactly four words (one control word and
three literals). The test passes in the PDP-6 simulator.

Root cause of the prior encoder error: after the last literal group,
`jumpn 2,d6v009_enc_group` fell through into the next physically adjacent
label, `d6v009_zero_scan`, when AC2 reached zero. The zero-run loop then
continued consuming the output capacity, eventually returning -1. A new
unconditional jump to the encoder completion label fixes the fallthrough.

IMPORTANT: This is ONLY an encoder-output-size test. A full decoder test
has NOT passed. The v009 encoder emits v006-like counted control groups,
but `decompressor_v009.inc` is a D6LZ36 control-bitmap decoder, with an
experimental zero-run extension. These two representations are incompatible.
The stored `test_decode_v013.s` retains the attempted full round trip for
later format alignment; it currently times out and must not be treated as
passing. Next implement a matching universal v006-format PDP-6 decoder and
verify exact decoded contents, then add the bounded native match encoder.
