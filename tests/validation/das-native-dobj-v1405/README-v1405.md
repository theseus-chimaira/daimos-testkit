# Native DAS relocatable DOBJ1 output v1405

The v1405 regression checks the actual on-target compiler-to-linker
toolchain: native KCC creates packed ASCII7 assembler source; native
two-phase DAS `-A -C` creates a relocatable DOBJ1; native DLINK links
that object with real startup and syscall objects; the resulting DXR
executes under DAIMOS.  This is not a host object-conversion test.

Native DAS1 exports globals through an object-only DASIR2 extension.
Native DAS2 reconstructs the symbol store from DASIR2 and appends
globals and relocation metadata to temporary wordfiles.  It streams
the DOBJ1 code, symbol and relocation records with the existing
bounded output queue, retaining the same DOBJ1 wire format as host
DAS.  The ordinary DXR path retains its original DASIR2 layout.

## Running the suite

First run the accepted v1371 full distribution, v1401 native compiler,
and v1403 native linker suites.  Build the experimental native DAS
phase executables from the v1405 source into an isolated directory;
do not replace the production DAS binaries.  From daimos-testkit:

```
export TMPDIR=$HOME/tmp
export PDP10_PREFIX=$HOME/cross
DAIMOS_REPO=/path/to/staged/DAIMOS \
NATIVE_DAS_BUILD=$TMPDIR/das-native-dobj-v1405-final-build/native \
sh tests/validation/das-native-dobj-v1405/run-v1405.sh
```

The runner refuses to overwrite its default versioned output tree.
It constructs independent host reference assembly, DOBJ and DXR
objects, stages a complete grouped 237-file D6FS image, checks it
CLEAN, and uses isolated simulator media for guest acceptance.  The
default probe generator emits **29 strict checks** for five C89
modules: external function caller/provider, external data
caller/provider, and local-data references.  Every native KCC
assembly file and DAS DOBJ must match its independently produced
host reference; three native DLINK image outputs must match the
host; all three resulting C89 executables must return status 7.

The optional `V1405_PROBES` override is for *diagnostic* runs only;
the complete default suite is required for source acceptance.

## Reproducibility note

An expanded 29/29 run passed on the original v1405 native build.
After a host-only source conditional was corrected, DAS1/DAS2 were
rebuilt; their instruction-level output differed only in numeric
diagnostic identifiers generated from source line numbers.  The
second 29-probe run passed 16 probes, then guest KCC failed to return
while compiling the local-data fixture as probe 17.  That run was
terminated after preserving the transcript.  An isolated fresh-boot
test of the same local-data compile, object assembly, link and run
passed 7/7.  Native DAS v1405 also passed all 17 existing v1402
compatibility tests when rebuilt from the final source.

This is **not** full sustained-compile acceptance.  Investigate
accumulated guest working-set, swap and filesystem/proc lifecycle
before claiming repeatable self-hosting.  No host-produced DOBJ
substitution is permitted in the final native acceptance.

## Remaining qualification

The five-module native test does not exercise the full assembler
grammar, unusual `.set` relocation expressions, all left-half byte
pointer forms, invalid-file mutation, exhaustive disk-fault recovery,
or the 96K self-hosting peak-memory target.  Further targeted
regressions and full source coverage are necessary before replacing
the installed compiler and assembler.  Memory/code-size optimization
of KCORE remains deferred to the final KCORE work stage.
