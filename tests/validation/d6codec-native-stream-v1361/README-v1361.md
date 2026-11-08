# v1361: native PDP-6 grouped-stream resumable proof

Run using a DAIMOS worktree with current linked KCORE/MRES DXRs:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-native-stream-v1361/run-v1361.sh
```

The first test runs the staged `d6codec_stream_v1361.s` assembly
decoder with one-word input windows. It checks a literal group,
a control/descriptor split zero run, a 30-token all-zero run using
15 packed descriptor words, malformed group-count rejection, and
invalid physical destination-endpoint rejection. An independent
second native test reads the host golden encoded first 128 words
of the current linked KCORE DXR, feeding the decoder one compressed
word per call and comparing all reconstructed words to the source.

Both PDP-6 simulator tests PASS. The standalone native object contains
230 36-bit instruction words, no data or BSS, and 82 relocations.
The caller owns a **26-word** state block including 15 descriptor
words. The engine uses AC17 briefly for its private compressed-word
fetch subroutine; caller call frames are additional. Source, state and
output geometry is checked on entry; overlapping source/output and
state/output ranges are rejected. This staged assembler-only entry
clobbers AC4..AC16; it is not yet a C-callable kernel ABI.

Critical remaining requirement: this 230-word non-position-independent
staged core has **not** been installed at octal 000060, and its
relocation/low-core overlap and actual Stage-1 memory footprint have
not been accepted. No production decoder, loader or image was changed.
Additional malformed-stream, source-refill/provider and nested stack
regressions are required before any boot-format migration.
