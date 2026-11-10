# End-to-end PDP-6 encoder/decoder comparison v1429

Date: 2026-11-10. Purpose: choose a fast, compact, memory-efficient
pair for compression and restoration of mutable 36-bit RAM.
All measurements use three actual DSH physical-memory captures
from v1426 and exact independently validated reference formats.
No in-kernel process compression is activated.

Four native KCC encoder implementations are compared:

- D6LZ36: a test-only direct-memory, bounded-output C89 port
  using the same greedy 128-word history search as existing D6LZ.
- Block: a test-only C89 direct-memory encoder reproducing v1424
  block streams exactly.
- Grouped: a test-only C89 direct-memory encoder reproducing the
  v1420 grouped streams exactly.
- RAM RLE: unmodified actual DAIMOS kpack_ram_rle_v1376.c,
  including separate exact-size measurement and decoder.

The testkit variants have no static DATA/BSS or heap allocation,
use caller-owned output and reproduce their independent host
encoders word-for-word. 28 native encoder acceptance fixtures
PASS (three real memory states plus four controls, four codecs).
Three separately checked RAM RLE decode-only fixtures PASS.

## Raw/encoded lengths (36-bit words)

| State | Raw | D6LZ36 | Grouped | Block | RAM RLE |
|---|---:|---:|---:|---:|---:|
| Idle | 3200 | 277 | 246 | 280 | 263 |
| Variables | 3200 | 508 | 439 | 532 | 537 |
| Function | 5248 | 614 | 524 | 656 | 677 |

## Standalone KCC code sizes

| Native implementation | TEXT words |
|---|---:|
| Test D6LZ36 memory encoder only | 174 |
| Test block encoder only | 227 |
| Test grouped encoder only | 264 |
| Unmodified RAM RLE measure + encode + decode | 448 |
| Production BLT D6LZ36 decoder + runtime adapter | 96 |
| Staged v1424 block decoder + adapter | 164 |
| Staged v1420 grouped decoder + adapter | 364 |

Indicative total TEXT for the presently measured code:
D6LZ36 270, block 391, grouped 628, RAM RLE 448 words.
This is not a final linked/folded KCORE or equal-API total:
the test encoders are prototypes, and native code residency and
restore transaction overhead are not yet accepted.

PDP-6 stack-canary measurements, including test-call overhead:
D6LZ36 17 words, block 17, grouped 66, RAM RLE 22 words.

## Native encoder instruction counts

| Encoder | Idle | Variables | Function |
|---|---:|---:|---:|
| RAM RLE, encode only | 116k | 129k | 202k |
| RAM RLE, extra exact-size measurement | 112k | 122k | 192k |
| Grouped | 611k | 1301k | 1586k |
| Block | 686k | 1480k | 1836k |
| D6LZ36 | 1961k | 2930k | 3641k |

The range search has approximately 0.5%-1% precision.
Native PDP-6 SIMH STEP counts BLT as one instruction; these
are NOT measured PDP-6 execution times. LZ match-search loops
dominate encoder work, so that limitation does not reverse the
substantial gap among encoders.

## Real PDP-6 decoder instruction counts

| Decoder | Idle | Variables | Function |
|---|---:|---:|---:|
| RAM RLE unmodified C | 38.7k | 42.7k | 67.5k |
| Grouped native assembly | 9.1k | 18.0k | 23.1k |
| Block v1424 native assembly | 1.7k | 3.4k | 5.1k |
| D6LZ36 BLT assembly | 3.2k | 5.8k | 7.3k |

## Full encode/decode cycles, native instruction counts

| Pair | Idle | Variables | Function |
|---|---:|---:|---:|
| RAM RLE, encode + decode | 154k | 172k | 269k |
| RAM RLE, including exact-size prepass | 265k | 293k | 460k |
| Grouped | 620k | 1319k | 1609k |
| Block | 687k | 1484k | 1841k |
| D6LZ36 + BLT | 1964k | 2936k | 3648k |

Other pair cycles omit any future separate exact-size prepass.
RAM RLE remains faster even after charging its existing prepass.
Compression and decompression are both important for process
packing: do not select by compressed length or decoder speed alone.

## Assessment and future engineering gate

Use bounded RAM RLE as the leading baseline for an integrated
mutable-process codec. Then optimize its decoder with BLT for
literal runs, zero runs and repeated words while retaining
validation. Investigate compact native encoder/decoder assembly
to reduce the 448-word C code budget and compare the whole
implementation against D6LZ36 (270), block (391) and grouped
(628) prototype combinations. Avoid permanent dual codecs.

Optional experimental alternative: RLE with a very small,
fixed-cost match dictionary (8 or 16 entries) to capture
nonadjacent repeats without scanning 128 backward distances.
This has NOT yet been implemented or benchmarked. Any such
enhancement must justify both the RAM dictionary cost and CPU
time by sufficient additional compressed memory savings.

Reproduce after a v1426 capture:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export DAIMOS_REPO=/path/to/versioned-DAIMOS
    export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
    sh tests/validation/d6codec-encoder-v1429/run-v1429.sh

For timing, run measure-speed-v1429.py with the testkit,
TMPDIR work and PDP10_PREFIX. The script supports separate
codecs named d6lz, grouped, block, rle, rle_measure,
rle_decode and all three real DSH states.
