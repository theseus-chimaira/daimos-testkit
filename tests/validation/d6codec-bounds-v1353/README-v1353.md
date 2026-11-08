# D6 codec native bounded decoder regression v1353

This test exercises the staged DAIMOS `d6codec_decode_v053.s` through its
v055 saved-register adapter on the actual PDP-6 simulator, not through a
host-only reference implementation. It does not enable grouped compressed
images or replace the production D6LZ36 decoder.

Run from the `daimos-testkit` checkout with:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-bounds-v1353/run-v1353.sh
```

The fixture checks that the decoder rejects:

- nonzero control bits outside the declared one-token group;
- a nonzero unused right descriptor halfword;
- source end address beyond physical 18-bit address space;
- destination end address beyond physical 18-bit address space;
- source addresses with nonzero bits beyond bit 17;
- nonempty source/output overlap.

It also verifies that an invalid source endpoint does not modify the
output sentinel and that a canonical, non-overlapping literal succeeds
without modifying the compressed source. Failure codes 1 through 4
identify the negative-test stage; 5 through 7 identify the valid
decode, decoded value, or input preservation stage respectively.

Witness: this fixture fails with code 1 against the unmodified DAIMOS
v1351 staged decoder, which accepted a nonzero unused control flag.
The same fixture passes against the v1353 hardened staged decoder.

The separate v055 native full-DXR ABI/roundtrip test must continue to
pass. Further fuzz, precise stack-high-water, and full linked KCORE
consumer integration remain separate acceptance gates.
