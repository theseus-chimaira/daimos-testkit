# Fixed-low-core block decoder v1458 native acceptance

Versioned tests for the 53-word file/executable block decoder
copied to address 000060, plus its 58-word VFS adapter.
**This does not claim a successful Stage-1 cold boot.**

Run from daimos-testkit:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export DAIMOS_REPO=/path/to/the/v1458/DAIMOS/worktree
    sh tests/validation/d6codec-fixed-v1458/run-v1458.sh

`run-v1458.sh` measures physical TEXT and relocations, then
runs 11 native low-core unit tests, 23 native VFS/streaming,
malformed, full-DXR and stack tests, and five genuine Stage-1
source assemblies with v1458. All files and logs remain in
`$TMPDIR/d6codec-fixed-v1458-acceptance`.

The low-core test adds the decoder source into the same
assembler unit as the Stage-1-like BLT relocation. This is
intentional: calculating an offset between external symbols
from two independent DOBJ1 objects is not supported. The
installed image includes its LDB byte-pointer word.

The fixed VFS adapter is part of the DAIMOS source branch,
and its core call goes straight to `000060` to ensure one
and only one decoder is used. Nine malformed compressed data
tests include opcode, origin, reserved bits, lengths,
truncation, source count and trailing payload. Invalid buffer
aliasing is excluded as a kernel-caller contract, not treated
as a malformed encoded stream.

The assembler-only Stage-1 tests cannot verify simulator
boot behavior, TSFS media access, low-memory EXEC/PURE
restore, or MM integration. Those remain separate acceptance
requirements before selecting v1458 in the build.
