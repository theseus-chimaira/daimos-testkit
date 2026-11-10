# Native PDP-6 zero-bitmap process-memory codec experiment v1432

Date: 2026-11-10. Experimental **test-only** RAM codec, developed
to evaluate whether swapless TSFS needs mutable-memory compression.
No production KCORE, MRES, Stage-1, DSH, MM, TSFS or boot configuration
is changed. These are genuine PDP-6 native instruction counts measured
on three real DSH process-memory snapshots captured in v1426.

## A deliberately simpler representation

For each consecutive group of at most 36 original 36-bit words, emit
one 36-bit presence bitmap, followed by the original nonzero words
in increasing address order. A one bit means a literal word is present,
and zero means to reconstruct a zero word. Bit 35 is the first word
in the group, bit 0 is the 36th. The caller already knows the exact
number of original words, so a short last group requires no extra
length field. Neither direction uses a sliding window, history
table, filesystem I/O, memory allocator, heap or static buffers.

The v1432 native assembly is 55 total TEXT words (including encode,
decode and a shared error return), zero DATA/BSS, with only
AC-register working state. Both operations require disjoint
caller-owned source/destination extents. The prototype clobbers
registers and does not claim production ABI integration or
restart/rollback semantics; hardened validation of unused low
bits in a partial final bitmap would be necessary before adoption.

## Exact real DSH data sizes

The real DSH process was captured read-only after boot and login,
after six SET commands, and after defining/executing a function.
Its executable is **not currently PURE-tagged**, so each suffix
assumes the future PURE-prefix-drop policy; no actual process
has been evicted. The 114-word sector-alignment TEXT tail is included.

| State | Raw suffix | Nonzero | Packed bitmap | Saved words |
|---|---:|---:|---:|---:|
| Idle | 3,200 | 225 | 314 | 2,886 |
| Six variables | 3,200 | 435 | 524 | 2,676 |
| Function | 5,248 | 531 | 677 | 4,571 |

All three input SHA256 hashes are recorded in results-v1432.tsv,
and checked against the actual v1426 snapshots. Zero overhead
assumptions are not hidden: each bitmap represents exactly
36 words, and all nonzero words are stored verbatim.

## Exact native PDP-6 instruction counts

Native tests fully reconstruct every word of all three process
snapshots and five additional boundary patterns. The encode-only
and decode-only step counts exclude the test comparison loops.

| State | Encoder instructions | Decoder instructions | Encoder s at 0.25 MIPS | Decoder s | Combined s |
|---|---:|---:|---:|---:|---:|
| Idle | 24,658 | 30,565 | 0.0986 | 0.1223 | 0.2209 |
| Six variables | 25,918 | 31,615 | 0.1037 | 0.1265 | 0.2302 |
| Function | 41,400 | 50,926 | 0.1656 | 0.2037 | 0.3693 |

SIMH counts **instructions**. The time columns are arithmetical
estimates assuming the user's nominal 250,000 instructions/sec,
NOT measurements of hardware elapsed time, PDP-6 cycles, or MM
transaction overhead. This codec does not execute BLT, so it
does not hide long multiword BLT transfers in its instruction count.

The previous RLE v1376 native encode/decode counts, on the same
snapshots, were approximately 115k+39k, 129k+43k and 202k+68k
instructions. Full-search LZ encoders consumed 650k to more than
3 million native instructions per snapshot. The bitmap prototype
is the first experimentally tested pair in this series whose
**two directions both fit the desired 0.1-0.5 second budget**
at nominal 0.25 MIPS, while requiring only 55 TEXT words.

## Reproduction

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
    sh tests/validation/d6codec-compressor-v1432/run-v1432.sh

For the additional exact native instruction-count run:

    BITMAP_SPEED_V1432=1 \
      sh tests/validation/d6codec-compressor-v1432/run-v1432.sh

The testkit needs the original v1426 physical process snapshots
under $TMPDIR/d6codec-shell-live-v1426. Test outputs and
guest memory copies remain in $TMPDIR; raw user-memory bytes
are not committed. The run script tests the assembly with
native PDP-6 DAS/P10RUN. The two versioned TSV files hold
reference lengths/hashes and measured instruction counts.

## System design implications and limitations

The existing v1381/v1384 **inactive swapless PURE-only**
prototype can release an entire reconstructible immutable
prefix with no mutable compression. In DSH this would reclaim
15,232 of 18,432 words at idle, leaving a 3,200-word raw
suffix. Bitmap packing could then recover an *additional*
2,886 words while retaining exactly 314 words. At 32K,
that extra space is about 8.8 percent of physical core,
before packed-owner metadata or linkage overhead.

For a function-heavy DSH, the potential additional saving
is 4,571 words or 14.0 percent of a 32K core. Actual net
savings require fully safe and allocation-accounted MM
transactions, verified APR restore headroom and live
PURE-enabled execution: none is implemented here.

The proposed activation policy is **not every SLEEP**. A shell
may wake for each terminal keystroke. Releasing PURE text
and reading it back from DECtape on each input would dominate
latency. Only cold inactive victims under demonstrated memory
pressure could qualify, with capacity/admission thresholds and
conservative recent-use exclusions. A free-RAM/fragmentation
experiment in an integrated 32K/48K TSFS guest should decide
whether even the 55-word codec deserves permanent residency.

DEC TU56 contemporary specifications, for context:
https://www.pdp8online.com/tu56/tu56.shtml. Start/turnaround
are on the order of 0.15/0.2 s; full-tape positioning
can take about 30 s. These are *hardware transport*
figures, not measured DAIMOS TSFS operations. The tape
would be used to restore the PURE executable, not to
store the packed mutable process suffix.

**Recommendation:** prioritize the PURE-only lifecycle first.
Keep this 55-word bitmap codec as a demonstrated, optional
candidate; add it only if a measured 32K/48K workload benefits
enough to offset code/metadata/fragmentation and cold-wake
TSFS activity. Do not deploy exhaustive LZ encoding in KCORE.
