# Actual PDP-6 DSH RAM capture and codec comparison v1426

Date: 2026-11-10. This supersedes synthetic-only DSH estimates
for the three captured runtime states. No production files or boot
media are edited.

## Method

The v1426 capture script copies all attached boot media to a private
TMPDIR, makes a headless simulator configuration, starts real PDP-6
DAIMOS, waits for CTY LOGIN, logs in as ROOT, and enters real DSH.
It stops SIMH with Ctrl-E and uses only read-only EXAMINE commands.

The current process table base, slot limit, and active slot come
from exact linked KCORE symbols, not assumed addresses. A resident
process is accepted as DSH only if five instruction opcode halves
from its relocated memory match the actual DSH executable and
the exact DSH link map. The script validates the physical extent,
text/data geometry, complete address enumeration and word widths.
Each 36-bit word is recorded as one little-endian 64-bit host slot.

It captures three states, returning to the guest between them:

1. DSH idle at the ROOT login prompt.
2. After six real SET commands and ECHO DSH1426COMMANDOK.
3. After DEF FOO DO ECHO FUNCTIONOK DONE and executing FOO.

The loader may relocate DSH when the heap grows. The script
reexamines the live process descriptor and proves that the five
linked instruction signatures match again after each capture.
Neither process count nor memory addresses are hardcoded.

## Reproduce

Use an existing full 256K PDP-6 DSK-root DAIMOS build. Set:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
    export DAIMOS_CODEC_REPO=/path/to/DAIMOS-v1424-experiment
    export BOOT=$HOME/git/DAIMOS/build/system/boot/pdp6

From daimos-testkit:

    python3 -B tests/validation/d6codec-shell-live-v1426/capture-v1426.py \
      --simh "$PDP10_PREFIX/bin/pdp6" \
      --boot-ini "$BOOT/boot.ini" --kcore-map "$BOOT/kcore.map" \
      --dsh-dxr "$BOOT/userland-build/userland/dsh.dxr" \
      --dsh-map "$BOOT/userland-build/userland/dsh.map" \
      --output "$TMPDIR/d6codec-shell-live-v1426"

    sh tests/validation/d6codec-shell-live-v1426/run-native-v1426.sh
    python3 -B tests/validation/d6codec-shell-live-v1426/selftest-v1426.py

The first command produces three physical RAM snapshots, JSON
metadata, a debugger transcript, a media-copy manifest and an
isolated SIMH log. The second compiles the **actual** host-side
DAIMOS kpack_ram_rle_v1376.c as a shared library, runs all three
independent codecs, and generates nine native PDP-6 acceptance
fixtures. Its C89/C99 compiler selection follows the existing
v1376 implementation; this Python test does not add C code.

The raw 64-bit-slot memory captures remain only in TMPDIR; they
are deliberately NOT committed to Git because real user process
memory may contain private contents. The documented test
transcript and complete reproduction method are version-controlled.
The six-row results-live-v1426.tsv contains measured counts and
SHA256 hashes identifying the three original physical-suffix
snapshots, without publishing their memory contents.

## Actual process results

The exact DSH DXR2 header has 15,331 initialized words, including
15,330 TEXT words, and 1,011 BSS words. The current DSH executable
does not set PURE, so the 15,232-word text-prefix omission is
prospective. The recorded physical suffix includes 114 trailing
TEXT words and all writable data, BSS, stack, heap and padding.
No process was really evicted or packed.

| DSH state | Full resident VM | Physical base (octal) | Suffix raw | Nonzero |
|---|---:|---|---:|---:|
| Idle | 18,432 | 662000 | 3,200 | 225 |
| Six variables | 18,432 | 662000 | 3,200 | 435 |
| Function | 20,480 | 656000 | 5,248 | 531 |

The initial and post-variable snapshots differ in 214 words.
Function allocation grows the process VM by two 1,024-word APR
allocation units; its physical base moves, and its linked code
signature is revalidated after the move.

## Exact payload sizes, in 36-bit words

| Physical retained suffix | Raw | Grouped v1420 | Block v1424 | RAM RLE v1376 |
|---|---:|---:|---:|---:|
| Idle | 3,200 | 246 | 280 | 263 |
| After variables | 3,200 | 439 | 532 | 537 |
| After function | 5,248 | 524 | 656 | 677 |

If instead we omit the 114-word trailing TEXT sector fragment:

| Writable-only suffix | Raw | Grouped | Block | RAM RLE |
|---|---:|---:|---:|---:|
| Idle | 3,086 | 128 | 166 | 149 |
| After variables | 3,086 | 324 | 418 | 423 |
| After function | 5,134 | 408 | 542 | 563 |

These are encoded payload counts, excluding storage metadata,
transient workspaces, encoder/decoder TEXT, and any additional MM
transaction machinery. The source C RAM RLE codec already has
native measure/encode/decode routines; grouped and block have
native decode engines but currently only experimental host
encoders. Comparing decoder text with the full v1376 encode/decode
code would NOT be an apples-to-apples resident RAM budget.

The MM subsystem can allocate packed extents to exact word
length with alignment 1, as the older inactive PACKED_PROCESS
v1 reserve prototype demonstrates. Actual compressed swapless
admission and exact packed ownership are NOT production features.
The existing DSH still occupies the complete 18,432/20,480-word
VM until PURE release and compression are implemented and tested.

## Native correctness

The host implementations roundtrip the three actual snapshots
under grouped, block and the real v1376 C RAM codec, for both
physical and writable-only suffixes (18 full roundtrips).

The PDP-6 simulator also executed nine actual codec checks on
the complete physical suffixes: three grouped v1420 decodes,
three block v1424 decodes, and three complete v1376 native
measure/encode/decode plus byte-for-byte compressed stream and
decoded word comparison. All nine PASS.

No real target encoder has yet been implemented for grouped
or v1424 block streams. Current RAM RLE v1376 implementation
has standalone code cost reported earlier as 449 words including
both encoder and decoder. Real MM/PI/ownership/stack regression,
compression CPU cost, peak RAM during encoding and full
restoration remain separate work. This report must not be read
as deployment acceptance.

The host selftest independently checks exact debugger output
parsing, duplicate/missing addresses, nonmatching DSH signatures,
ambiguous matching processes, and out-of-range process extents.
