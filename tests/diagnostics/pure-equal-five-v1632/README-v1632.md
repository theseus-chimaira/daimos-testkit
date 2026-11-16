# P1-E v1632: equal-five-child 48K physical RAM measurement

The source-identical v1631 PURE-on/off comparison established a
process-admission regression: PURE on could keep five PACKED children
but refused the sixth RUN, whereas PURE off successfully admitted
six fully resident children. Its physical MM snapshots did not have
equal child populations and were not a net RAM comparison.

This v1632 test replays the SAME original saved PURE-disabled
v1631 executable, KCORE, and private Type-551 TSFS media. SIMH
stops immediately after the original fifth child's `a` marker,
BEFORE the sixth RUN, while the parent and five children are alive.
It examines all original MM arena/extent words from the matching
KCORE map, then continues to the original `!u` and six child
completion markers/normal HALT.

    PURE_OFF_BUILD_V1631=/path/to/v1631/off/build \
        sh tests/diagnostics/pure-equal-five-v1632/replay-v1632.sh

The auditor compares that original physical snapshot with v1629's
existing source-matched PURE-on B-stage MM capture. The PURE-on
guest has five PACKED suffix owners, plus the original parent;
the disabled guest has five complete 010000-word resident child
APR images plus parent. Its source and compiled DXR, and KCORE
map, are BYTE-IDENTICAL to the enabled original. The module
package exists only in the enabled KINIT map.

| Original physical MM (octal) | PURE on, five PACKED | PURE off, five resident |
|---|---:|---:|
| Arena | 042562..140000 | 037224..140000 |
| Extent count | 022 | 023 |
| Occupied words | 057023 | 064224 |
| Free words | 016173 | 014330 |
| Largest 02000-aligned gap | 007000 | 012000 |

The exact difference in free physical words is `001643` octal
or **931 decimal words** in favor of PURE enabled. The enabled
arena begins `003336` octal (1758 decimal) words higher, accounting
for the installed PURE MRES resident size; the free difference
therefore already includes that module footprint at the sampled
times. Five omitted PURE prefixes gross 2560 decimal words; do
not substitute that gross number for the observed net difference.

**Important:** the PURE-on B point is AFTER its sixth RUN was
refused, while the PURE-off fifth `a` is BEFORE its sixth RUN.
The same parent and five child owners are live, but the minor
execution-history difference may account for temporary dynamic
MM-owner differences. The 931 words are genuine measured *sampled*
free RAM, not a completed whole-system peak or latency analysis.

Even with MORE free words, PURE-on has largest aligned gap 007000,
too small for a new 010000 APR process. PURE-off has an 012000
aligned gap and actually admits its sixth child. Thus the problem
is **fragmentation and contiguous placement**, not missing freed
prefix accounting. No allocator workaround or production code is
introduced here.

Run strict source and physical owner checks, including forged
PACKED-to-PROCESS and duplicated-off-owner negative controls:

    PURE_ON_CASE_V1632=/path/to/v1629/on \
    PURE_OFF_CASE_V1632=/path/to/v1631/off \
    PURE_ON_TRACE_V1632=/path/to/v1629/original/trace.clean \
    PURE_OFF_TRACE_V1632=/path/to/v1632/trace.clean \
        sh tests/diagnostics/pure-equal-five-v1632/run-audit-v1632.sh

Peak RAM, FULL relocated restore and rollback, PI6/immutable source
loss and any safe representation/compaction improvement remain open.
PURE must stay disabled by default until the net and contiguous
capacity objectives are reconciled.
