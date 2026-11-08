# v1363: full-buffer grouped D6CODEC Stage-1 in-place prototype

The production Stage-1 loaders already read the complete compressed
KINIT stream into RAM *after* the final decoded KINIT region before
calling D6LZ36. They do not use NEED_INPUT during the decompression
call. Stage-1 therefore needs no 230-word streaming v1361 engine,
no 26-word continuation state, and no decoder-copy to address 000060.

Run with a linked DAIMOS checkout and native PDP-6 toolchain:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-stage1-inline-v1363/run-v1363.sh
```

The versioned generator emits test-only alternatives for all five
loader sources, substituting the existing complete-buffer
`d6codec_v053_decode` at the actual *linked* Stage-1 address. It
replaces the fixed-address BLT copy and converts only the compressed
handoff, preserving all existing raw-image and tape-reading logic.
Original production sources are never modified. It assembles both
original and staged versions using DAS -F -K and converts each
staged DXR into a Stage-0 read-in paper-tape image at octal 000060.

The inspector confirms linked decoder symbols, actual read-in base,
code/BSS footprint below the Stage-1 stack at octal 020000, and
absence of the obsolete decoder entry in staged symbols. The
accepted prototype text word counts are:

| Stage-1 | Original | Staged | Increase | Staged BSS |
|---------|----------|--------|----------|------------|
| DSK     | 350      | 432    | 82       | 879        |
| DRM     | 342      | 424    | 82       | 879        |
| DTC     | 140      | 229    | 89       | 0          |
| MTC     | 106      | 195    | 89       | 0          |
| PTR     | 139      | 224    | 85       | 3          |

The DTC/MTC existing AC4 retains compressed length across their
read_word routine; the staged handoff moves it directly into AC2
before reusing AC4 for decoded word count. This avoids new BSS.
Because the complete-buffer decoder clobbers scratch registers,
DTC/MTC preserve the KINIT entry AC5 and word count AC13 on their
existing low-core stack; PTR preserves entry AC16. DSK/DRM use
their existing memory-resident header fields.

Ten **native PDP-6** tests link the actual generated handoff body
at address 000060 and call it with a valid one-literal grouped stream
or an invalid control. Each checks correct transfer to KINIT and
entry stack on success, or decoder failure with the output guard
unchanged on rejection. The assembled Stage-1 artifacts themselves
have not been booted from all five devices. The tests use tiny
in-memory streams rather than disk/tape controllers.

This is a staged, repeatable integration prototype, not production
image conversion. Native VFS still needs a resumable decoder and
no mixed-format boot/runtime images may be deployed.
