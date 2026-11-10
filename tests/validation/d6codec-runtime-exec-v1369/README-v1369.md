# v1369: functional grouped executable, PURE and TSFS runtime tests

Run with the current PDP-6 kernel DXR build:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-runtime-exec-v1369/run-v1369.sh
```

All work is performed in `$TMPDIR/d6codec-runtime-v1369`.
Production DAIMOS sources, boot images, KCORE, media and filename
selection remain unchanged. The grouped DXR producer is a **test
utility**, not a new production writer or mixed-format detector.

`grouped_dxr_v1369.py` converts an uncompressed linked DXR1/DXR2
binary (36-bit words stored in 64-bit LE containers) into a grouped
compressed DXR2. It preserves the entry address, flags other than
the existing COMPRESSED flag, BSS extent, TX2 text-word count and
all relocation bitmap words. It strictly checks the original image
size, flags, entry, text header, relocation map, word bounds and
the independently decoded grouped payload before publishing a
separately named versioned file. Existing and legacy-named targets
cannot be overwritten; a second compression attempt is rejected.

`marker-v1369.c` compiles with the actual PDP-6 C89 toolchain and
links as a two-instruction DXR. Native PDP-6 tests use the real,
unmodified `exec_load_process` and a deterministic fake filesystem
and VM allocator to load its *grouped DXR2* image. The test calls
the decoded compiled marker directly and checks its octal 012345
return value. The same four EXEC cases run against the 390-word
real linked `tape-mres.dxr` image, compressed to 379 grouped words;
this exercises repeated seven-word VFS short reads and checks every
decoded word. In both cases, tests prove:

- Successful grouped EXEC load, correct VM contents and entry/commit.
- PURE execution: actual header flag and saved backing metadata.
- Malformed first token: VM destroyed, no runnable process published.
- VFS read/EOF failure: VM destroyed without a swap attachment.

The fixture also extracts the **exact** `proc_swap_reload_pure`
implementation from DAIMOS (not a reimplementation), supplies an
isolated validated-vnode lookup stub, evicts the previous VM text,
and verifies grouped immutable PURE backing reloads all image words.
Malformed backing fails closed. The actual vnode unpacker and real
filesystem provider remain independent tests.

TSFS coverage uses the real, unmodified `tsfs_runtime.s` entry
and its read/copy/free path. A full 0400-octal-word restart extent
with a repeating 040-word pattern compresses to 35 grouped words,
fitting within the existing one-block restart bound (0176 words).
The successful read returns the expected 020 words at logical
offset 010 and frees its transient 0400-word decode allocation.
An invalid grouped control word produces a negative TSFS error,
frees the allocation and never publishes an output buffer.

**These are native functional integration tests, not a full DAIMOS
cold boot on grouped filesystem media.** The filesystem and VM
helpers are deterministic stubs. The existing compressed DXR flag
does not identify the codec, so staged grouped files MUST NOT be
mixed with D6LZ36 files in any production root filesystem. Final
work requires the entire producer/media/kernel format cutover,
real provider stack/failure tests and an end-to-end grouped cold
boot into INIT/LOGIN/RUN.
