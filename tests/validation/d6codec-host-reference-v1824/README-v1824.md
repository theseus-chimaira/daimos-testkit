# v1824: production host D6 block codec against independent v1421

The untracked historical v1452 host test exercised a distinct useful
regression: compare every 36-bit encoded output word from the host
`d6block_compress_v1452` implementation with the independent Python
v1421 reference, not merely with a permissive decoder roundtrip.
The old test assumed exactly 29 boot DXRs; the current source-matched
build contains additional removable-system images and a separate DSH
userland DXR.

`run-v1824.sh` compiles the **actual DAIMOS production source**
`tools/host/d6block-codec-v1452.c` as a temporary shared library,
then `check-host-v1824.py` tests every current boot directory DXR,
the full current DSH DXR, and eight deterministic pathological
streams. It requires at least 20 DXR files and the KCORE, KINIT,
and DSK Stage-1 identities, but does not freeze the exact count.

Each input is compressed by the independent Python v1421 reference
and by the production C function. Every packed 36-bit word must
match exactly. The actual C strict decoder must also return the
original decoded words and reject seven invalid/trailing stream
cases. The Python reference is loaded from the separate committed
v1421 generator. No DAIMOS decoder source is duplicated in the test.

Command in daimos-testkit:

    make test-d6codec-host-reference-v1824

Verified with 31 actual boot DXRs, the DSH image and eight stress
streams, totaling 94,276 source words. Every encoded stream was
byte-for-byte identical; all seven malformed/trailing cases were
rejected. This is a **host codec regression**, not a native guest
boot, DTC/MTC acceptance, or independent on-device decompression.
