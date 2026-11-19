# Native DAS relocatable-output safety gate v1404

This is a completed negative regression, not implementation of the
native DOBJ1 writer.  The previous native DAS driver did not accept
`-C`; an incorrect partial implementation could instead emit a DXR
under a DOBJ filename.  The v1404 DAS1 parser recognizes `-C`,
retains object-mode state in its assembly context, and explicitly
refuses object output until symbol and relocation serialization are
implemented.  The phase-state format reserves an object-mode bit
for subsequent correct DAS1/DAS2 transport.

The runner rebuilds a full grouped 237-file DAIMOS root with v1401
KCC, newly compiled v1404 native DAS/DAS1/DAS2 and normal DLINK.
It uses the accepted v1403 host DOBJ inputs only as fixture data.
All four strict PDP-6 simulator probes passed: native KCC compiles
the C89 fixture, normal native DAS -A direct-DXR assembly succeeds,
native DAS -A -C exits with status 1, and the rejected object file
cannot be opened by CMP.  No installed binaries or boot media change.

To reproduce, provide the v1404 native DAS build directory and an
isolated DAIMOS checkout after accepting v1403:

```
export TMPDIR=$HOME/tmp
DAIMOS_REPO=/path/to/DAIMOS \
V1404_NATIVE_DAS=/path/to/v1404/native-das \
sh tests/validation/das-native-object-gate-v1404/run-v1404.sh
```

The remaining implementation must correctly preserve `.globl`,
undefined symbol references, section-relative addends and all
relocation types through the DASIR2 stream.  It must emit actual
DOBJ1 records with bounded resident RAM.  Until that implementation
is accepted, native `-C` must fail instead of producing a misleading
or silently corrupted object file.
