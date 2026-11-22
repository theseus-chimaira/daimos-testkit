# DAIMOS/PDP-10 host DLINK and P10RUN source regressions v1812

Date: 2026-11-22. Scope: host tool correctness. The native DAIMOS
file-backed DLINK has a separately compiled target build, but no new
in-guest execution acceptance is implied here.

The real DAS `-C -F` assembler produces DOBJ1 inputs with an OPTIONAL
undefined declaration and a NEEDED symbol relocation. The test builds
the *specified* DLINK and P10RUN sources with a host C89 compiler;
installed DLINK/P10RUN binaries are never used as oracles. It checks:

1. An unreferenced EXTERN can remain undefined in an executable.
2. A referenced EXTERN still fails if its provider is unavailable.
3. An archive containing OPTIONAL and NEEDED extracts only the needed
   member, identically to linking the provider object directly.
4. Right- and left-half symbol relocations obey the same rule.
5. P10RUN accepts a completed guest with expected zero status, but
   rejects `Step expired`, case-varied `Time expired`, mismatched exit
   status and the low-core breakpoint. The expiry cases retain an
   initialized zero examine result to expose the old false PASS.

Run from daimos-testkit with the DAIMOS source:

    make test-toolchain-extern-expiry-v1812 \
      PDP10_PREFIX="$HOME/cross" DAIMOS_REPO="$HOME/git/DAIMOS"

Run against the independently maintained tool checkout:

    make test-toolchain-extern-expiry-v1812 \
      PDP10_PREFIX="$HOME/cross" \
      PDP10_TOOLS_REPO="$HOME/git/pdp10-tools"

The former DAIMOS DLINK rejects OPTIONAL even when no relocation
references it. The former P10RUN source returns zero for both expiry
transcripts with the stale zero exit value. These failures were
reproduced as separate baseline controls before promoting the fixes.

The native DAIMOS linker uses a three-word stack bitmap of referenced
symbols and streams each DOBJ relocation table only once per object,
without resident BSS growth. Native source KCC/DAS assembly and linked
DXR creation are a separate compile/link gate, not a simulator run.

The opt-in real-SIMH test builds the same host sources, runs the
previously accepted v014 D6CODEC test under a real PDP-6 SIMH `go`,
then reruns the identical guest with an intentional one-step limit.
It requires the completed guest to PASS and the one-step result to
report `Step expired` and FAIL. Execute with:

    make test-toolchain-extern-expiry-simh-v1812 \
      PDP10_PREFIX="$HOME/cross" DAIMOS_REPO="$HOME/git/DAIMOS"

This is actual bare-machine simulator execution, not guest-native
DLINK running inside the DAIMOS operating system.
The same actual one-step run with the old P10RUN source returned a
false PASS, independently confirming that the source correction is
necessary. Its failure-control transcript was preserved under TMPDIR.
