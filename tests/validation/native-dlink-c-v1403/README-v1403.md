# Native DLINK C89 DOBJ1 acceptance v1403

This isolates the resident DLINK linker from the remaining native
DAS `-C` relocation writer.  The source is a genuine C89 program
compiled by the accepted v1401 host KCC and native KCC, not a hand-
written assembly substitute.  Host DAS produces the known-good DOBJ1
file; the standard CRT0 and syscall objects are independent inputs.

The versioned runner rebuilds a CLEAN 237-file grouped D6FS root
with the v1401 KCC phases and v1402 DAS phases, plus the DOBJ1 test
objects and exact host-linked DXR reference.  Run from daimos-testkit:

```
export TMPDIR=$HOME/tmp
export DAIMOS_REPO=/path/to/DAIMOS
export V1403_KCC_NATIVE=$TMPDIR/kcc-kgen-stack-lifetime-v1401-testkit/native
export V1403_DAS_NATIVE=$TMPDIR/das-native-ascii7-v1402-testkit-r2/native-das
sh tests/validation/native-dlink-c-v1403/run-v1403.sh
```

The five PDP-6 native checks require: native KCC C89 compilation with
exit code zero, byte-identical assembly to the independently compiled
host reference, native DLINK returning zero for DOBJ1+CRT0+syscall
input, byte-identical linked DXR against host DLINK, and execution
of the resulting C89 program with exit status 7.

All five tests pass in the isolated normal grouped boot.  This proves
native DLINK's basic DOBJ1 input and executable output path.  It does
not claim native DAS `-C` is supported or that the full native C89
pipeline has passed.  No production tools or media are installed.
