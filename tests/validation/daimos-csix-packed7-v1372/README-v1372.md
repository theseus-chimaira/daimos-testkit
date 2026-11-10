# v1372: documented C-SIX transcode from native packed ASCII7

Run from `daimos-testkit`:

```
DAIMOS_REPO=/path/to/staged/DAIMOS \
    sh tests/validation/daimos-csix-packed7-v1372/run-v1372.sh
```

For a repeat run against the already accepted full v1371 boot, set
`V1372_REUSE_VERIFIED_V1371=1`. Otherwise the full grouped cold-boot
and 237-file-root acceptance runs before the converter tests.

## Canonical representation, not a new source format

This milestone follows the existing C-SIX storage contract in
`pdp10-doc/KERNEL/SELFHOSTING.MD`: normal lowercase C source letters
map to uppercase raw SIXBIT; uppercase letters use `@A` through
`@Z`, and special ASCII punctuation uses `@@`, `@'`, `@<`, `@!`,
`@>` and `@-`. S6REC record boundaries are source newlines; tabs
expand to eight-column stops. C-SIX is syntax-blind and reversible.

The existing host `csix -e` now also accepts `csix -e -p` for
36-bit word files containing five packed ASCII7 characters per word,
as native KCC writes its assembly output. Both paths use **the same
host C-SIX encoder**. The host test packs the reference C89 source,
compares both S6REC outputs byte-for-byte, and decodes the result
back to the exact original source. Three malformed input classes
(nonzero after NUL padding, missing final newline, truncated word)
are rejected. CRLF normalization and eight-column tab expansion are
also tested. Existing `csix -e` and `csix -d` contracts are kept.

`userland/toolchain/csix_v1372.c` is the isolated C89 native encoder.
It streams word-sized 7-bit input into the existing `u_text_sink`
S6REC writer, with a 16-word input buffer and no line-sized source
buffer. The native encoder uses the same C-SIX escapes, CRLF/tab
handling and final-newline requirement. Failed conversions remove
their output file; it refuses to overwrite an existing file. The
linked uncompressed native DXR is **002700 octal image words plus
000106 octal BSS words**. DAS itself and its phase images remain
unchanged, with no extra resident source parser.

## PDP-6 native acceptance

The test builds a full grouped DAIMOS KCORE/KINIT with all 27 MRES
packages and creates an isolated copy of the complete 237-file v1371
D6FS root, plus four test-only entries: packed C source, canonical
reference S6REC, corrupt packed source, and the native CSIX program.

Under PDP-6 SIMH, native CSIX reads the packed source and writes
canonical S6REC, then native CMP compares the **actual 36-bit words**
against the host `csix -e` reference. `CAT` reads the generated
S6REC, preserving the C-SIX escapes. Native KCC also opens and
compiles that same S6REC input with a successful status. The native
converter rejects bad packed padding and leaves no output file.
An additional packed CRLF/tab fixture is converted and compared at
the native 36-bit-word level against host CSIX. Eight harness probes
PASS, plus the host encoder/decoder checks.

This is a C source-storage conversion acceptance, **not an
assembler/linker acceptance**. Resident DAS still expects ordinary
uppercase SIXBIT/S6REC assembly, not C-SIX encoded assembly. Its
existing `ASCII2SIX`/`SIX2ASCII` utilities provide character-line
conversion for ordinary S6REC; no DAS input-format expansion has
been merged. C-SIX's escapable representation makes the generated
file editable by tools that handle regular S6REC records.

## Newly isolated compiler bug / next priority

The installed native KCC compiler can emit **incorrect assembler
instructions** from a valid C89 source even though it returns zero.
In the isolated PDP-6 fixture, native KCC emits `FMPL 017,0` and
omits the expected `MOVEI` mnemonic, whereas the host KCC produces
`MOVEI 1,012345` and `POPJ 17,`. The defect reproduces with and
without the native `-O` switch; it occurs in packed output *before*
CSIX or DAS reads it. Therefore the native KCC -> DAS -> LINK ->
RUN path is **NOT yet accepted**, despite the successful C-SIX
roundtrip and KCC exit status. The compiler/emitter failure is the
highest-priority follow-up, ahead of any further size optimization.

No production image, resident KCORE/DAS, standard D6LZ36 format or
normal root Makefile is changed by this test. Every generated file
is versioned under `$TMPDIR/daimos-csix-packed7-v1372`.
