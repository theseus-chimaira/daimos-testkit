# Native DLINK DOBJ1/C89 execution regression v1403

This test isolates the DAIMOS-resident static linker from the still-open
native DAS `-C` relocatable-object writer.  Host KCC v1401 compiles the
C89 fixture and host DAS produces its DOBJ1 object.  The accepted
startup and syscall DOBJ1 inputs are staged without modifying their
contents.  The host linker independently produces a golden executable.

The isolated full-distribution D6FS test root contains the five v1401
native KCC phases, the three v1402 native DAS binaries, the normal
native DLINK binary, and five versioned fixtures.  The root passes
`d6fsck` as CLEAN before PDP-6 simulator execution.  Nothing is
installed into the production operating system, repository build or
boot media.

Run after the v1371, v1401 and v1402 suites have been accepted:

```
export TMPDIR=$HOME/tmp
DAIMOS_REPO=/path/to/staged/DAIMOS \
sh tests/validation/daimos-native-dlink-c89-v1403/run-v1403.sh
```

The five native guest probes require zero status for native KCC
compilation to packed ASCII7, native DAS `-A` assembly to a direct
DXR, and native DLINK linking the host-produced C89 DOBJ1 with CRT0
and syscall DOBJ1.  Guest CMP requires byte-identical native/host
linked images.  Running the native-linked program must return 7.
All five probes pass.

**Acceptance boundary:** The native linker is functional for this
small C89 program and its real startup/syscall relocations.  The
relocatable C object and runtime objects are still built by host
tools, not native DAS; the native-compiled ASCII7 is assembled to
a separate DXR, not the linked DOBJ.  This suite does **not** claim
complete native compiler-to-DOBJ-to-linker self-hosting.  The native
DAS1/DAS2 pipeline needs a correct bounded-memory DOBJ1 writer and
the associated global-symbol/relocation transport before that claim.
