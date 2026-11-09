# Native C89 DOBJ1 assembly, DLINK and execution v1411

This first positive native `DAS -A -C` acceptance uses the C89
`int main(void) { return 7; }` fixture from the accepted v1403
linker regression.  Host KCC v1410 compiles the independent reference
assembly; host DAS `-C` writes the reference DOBJ1 without `-F`.

The isolated 237-file grouped D6FS root contains v1410-native KCC,
the newly built v1411 native DAS/DAS1/DAS2 and unchanged native DLINK.
Five strict PDP-6 guest tests require native KCC compilation, native
relocatable-object output, byte-exact equality to host DAS's DOBJ1,
native DLINK success, and execution of the linked program with status 7.
All five pass.  CRT0 and syscall DOBJ runtime inputs remain staged
from the accepted host build; the **main** DOBJ is generated on target.

The native DOBJ1 writer uses five header words and disk-backed symbol
and relocation records.  It does not retain an in-memory array of
relocation entries.  Object-mode `-F` optimization is not yet supported
because peepholes must rewrite affected relocation records, not a DXR
bitmap.  This test's main program has no relocation records, so it
does **not** establish local/external relocation correctness or full
native runtime self-hosting.  Extend coverage to multiple C objects
with real local and external relocations before release acceptance.

Run only against staged sources and accepted v1403/v1410 artifacts:

```
export TMPDIR=$HOME/tmp
DAIMOS_REPO=/path/to/DAIMOS \
V1411_NATIVE_DAS=/path/to/native-das-v1411 \
sh tests/validation/das-native-dobj-c89-v1411/run-v1411.sh
```

The test uses cloned media.  No compiler, assembler, linker or kernel
binary is installed into production DAIMOS.
