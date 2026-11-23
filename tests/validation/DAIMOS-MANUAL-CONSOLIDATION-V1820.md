# Native manual inventory consolidation v1820

An old unmerged testkit branch included an executable/manpage
consistency check and an unrelated disposable-media host MKSWAP test.
The latter references `tools/host/mkswap`, now absent from production;
the current tools include `mkauxstore` and `d6swap` with different
contracts. The v1071 test is archived as historical evidence and is
not represented as current formatter acceptance.

The original v1073 manual inventory check is made source-authentic
to the current `userland/Makefile`. The new v1820 script derives the
current names from the four public program groups, standalone native
DXR build dependencies and `PUBLIC_MANUAL_NAMES`. It insists that
the public name sets match, validates all named SIXMD pages with the
installed `sixmd-check` tool, and verifies private `MOUNTALL` and
`DSHCOMP` pages plus the documented but uninstalled native `MKSWAP`.
It also validates manuals for every optional assembly utility actually
installed by the optional assembler Makefile.

The check deliberately does not infer a KCC manual at the old
`userland/manual/KCC.SIXMD` path, nor claim complete standalone
compiler packaging or a present native/host MKSWAP implementation.

Run `make test-native-manual-coverage-v1820` in daimos-testkit.
