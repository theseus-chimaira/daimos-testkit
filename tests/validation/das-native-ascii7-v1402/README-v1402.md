# Native DAS direct packed ASCII7 input v1402

The DAIMOS-resident DAS previously accepted only canonical uppercase
S6REC source despite documenting the ASCII input option `-A`.  Native
KCC produces a different source format: five ASCII7 characters in each
36-bit word, aligned at bit 29 with the low spare bit zero.  The v1402
native assembler adds an explicit `-A` reader sharing the existing
buffered word source.  Default input and `-S` remain S6REC.

Native input decodes the 36-bit words without a separate conversion
file or extra resident input buffer.  A short final word is padded
with zeros; spare-bit violations, embedded NUL and trailing words
after padding are rejected.  Assembler mnemonics and directives are
case-insensitive in both modes, while original symbol spelling and
quoted ASCII data remain unchanged.

## Reproduction

Run the accepted v1371 and v1401 compiler suites first.  From the
daimos-testkit repository, with a staged DAS v1402 worktree:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
DAIMOS_REPO=/path/to/DAIMOS \
DAS_REPO=/path/to/das-v1402 \
sh tests/validation/das-native-ascii7-v1402/run-v1402.sh
```

The runner refuses to overwrite an existing test directory.  It
copies DAS source into test storage, rebuilds all three native DAS
images with the accepted v1401 host compiler, and stages them
alongside all five v1401 native compiler phases in a fresh normal
237-file grouped D6FS root.  The pristine root passes `d6fsck` CLEAN;
all simulator commands use disposable media copies.  Production
images, source and installed binaries are never modified.

Seventeen native PDP-6 probes require successful status and exact
guest `CMP` with independently assembled host DXRs for uppercase
ASCII7, explicit S6REC, default S6REC, native KCC-generated lowercase
assembly, mixed-case quoted ASCII, and a runnable test image.  The
hand-written native-DAS-produced image exits with status 7 after
normal DAIMOS RUN.  Three malformed ASCII7 forms must be rejected.

The resulting acceptance proves native KCC-to-DAS assembly and native
DAS-to-RUN for a standalone assembly program.  It does not yet prove
native KCC-to-DAS DOBJ-to-DLINK-to-executed-C, native KCC self-hosting,
or a production toolchain installation.  The current native DAS
driver does not implement object (`-C`) mode; that release gate stays
open independently.
