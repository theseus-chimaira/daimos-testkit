# v1365: real grouped KINIT boot-image and five Stage-1 device paths

This test makes a **test-only** grouped D6CODEC image from the
actual current linked KINIT, not a synthetic KINIT or a truncated
128-word golden prefix. It does not install or alter production
boot media, Makefile format selection, or the resident KCORE decoder.

Run the entire PDP-6 media matrix:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-kinit-image-v1365/run-v1365.sh
```

The first step builds the current DAIMOS `kinit.words` through the
normal linker and `mkimage.sh` KCORE-slot update. The host generator
requires a valid DAIMON header, exact 18-bit decoded length,
in-range KINIT entry, 36-bit source words, and exact host codec
roundtrip. It checks decoded image plus stack reserve and compressed
staging against the chosen physical core before *atomically* writing
its separate versioned grouped image to `$TMPDIR`.

The accepted full-profile KINIT contained 32,670 decoded words,
29,023 grouped compressed words, with entry `053524` octal,
decoded end `0127636`, and staged input end `0220375`. The full
256K core limit `01000000` leaves abundant headroom. The test-only
stream uses the standard three-word DAIMON header: magic,
decoded_words,,entry_offset, and grouped_compressed_words,,0.

Each simulator test loads a separate generated Stage-1 from a real
Type-760 read-in paper tape at octal `000060`; those staged loaders
include v1363 direct-linked grouped complete-buffer decode and the
v1364 physical-memory guard. The tests package and consume the full
grouped KINIT stream using actual virtual controller media:

| Device | Stage-1 source | Grouped KINIT media |
|---|---|---|
| DSK270 | DSK | Four-member DBOOT DSK disks, `mkdsk` |
| DRM236 | DRM | Four-member DBOOT Type-236 drums, `mkdsk` |
| DTC0 | DTC | Type-136 DECtape, `mkdt` |
| MTC0 | MTC | Type-516 seven-track magnetic tape, `mktap` |
| PTR | PTR | Two separate paper tapes, `words2pt` with `TAPE2` change |

All **five actual Stage0->Stage1->KINIT-entry simulator paths PASS**.
The expected KINIT entry breakpoint `053524` is reached, and
the first decoded KINIT word at physical `030000` matches the
original real `kinit.words` stream. The code does not run KINIT
past the entry breakpoint: the linked runtime still uses D6LZ36.

Two additional full Type-136 DECtape negative tests corrupt the
boot header image length (staging/stack overflow) and the grouped
control word (zero-token invalid group). In both cases the staged
loader halts without reaching KINIT, and its decoded output at
`030000` remains zero. The suite also verifies the host grouped
producer refuses output with insufficient 32K physical memory and
an excessively large stack reserve without leaving partial files.

Remaining tests before production: damaged/truncated input on every
physical boot device, more KINIT memory checks beyond the first
word, cold-boot runtime behavior through filesystem initialization,
KCORE/VFS/EXEC/PURE/TSFS grouped consumers and atomic host producer
change. The five successful entry transfers are not proof of full
operating-system startup under the new codec.
