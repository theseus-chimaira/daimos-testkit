# P1-E v1631: original source-matched PURE-OFF 48K capacity control

The genuine v1629 48K PDP-6/TSFS/no-AUX/PURE workload admitted five
children and PACKED each retained 007000-word suffix, then refused
its sixth RUN for lack of a contiguous 010000 APR VM. The PURE
module itself consumes 003336 octal/1758 decimal resident words.

The v1631 control compiles the EXACT same C89 five-child guest and
KCORE with the same host GCC and PDP-6 assembler/linker. It changes
ONLY `DAIMOS_PURE_MRES_ENABLED=0` for the native 48K boot image.
Both images' saved `/SYSTEM/INIT` DXRs and linked KCORE maps compare
byte-for-byte, and `kinit.map` proves the PURE package is present
only in the enabled image.

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-capacity-baseline-v1631/run-v1631.sh

Original disabled-guest console: `aaaaa!uwwwwww` and normal HALT,
without any `PURE LOADED` marker. The `!u` is the original
source's explicit assertion that the *sixth* RUN was expected to
fail; this is a valid negative-control observation, NOT a normal
passing lifecycle test. In reality all six children were admitted
and printed their original successful `w` markers after parent
assertion cleanup. The PURE-enabled case had `aaaaax...LwwwwwZ`:
its sixth RUN really DID fail, and only five children completed.

The physical read-only replay uses an original SIMH console stop
immediately after the OFF guest's `aaaaa!u` marker, while the
parent is still alive. It prints every original MM arena/extent:

    PURE_OFF_BUILD_V1631=/path/to/off-case/build \
        sh tests/diagnostics/pure-capacity-baseline-v1631/replay-v1631.sh

Decoded off-case MM: one arena `037224..140000`, 025 octal extents,
seven unpinned full PROCESS images (six children plus parent)
contiguously placed from `046000..136000`. Physical occupied/free
are `074634/003720` octal, largest APR-aligned remaining gap
`002000`. No PACKED owner exists. The PURE-enabled B snapshot in
v1629 had arena `042562..140000`, five PACKED suffixes, free
`016173`, largest aligned gap `007000`. The lower arena-start
delta `042562-037224 = 003336` octal words exactly matches the
resident PURE MRES image length.

Run the original-source/physical audit with unsafe owner and
sixth-RUN marker negative controls:

    PURE_ON_CASE_V1631=/path/to/v1629/on-case \
    PURE_OFF_CASE_V1631=/path/to/v1631/off-case \
    PURE_OFF_TRACE_V1631=/path/to/off-replay/trace.clean \
        sh tests/diagnostics/pure-capacity-baseline-v1631/run-audit-v1631.sh

**Conclusion:** for this exact 48K process-admission workload,
PURE-enabled cannot admit a sixth child although PURE-disabled
can. The five 001000-word omitted PURE prefixes increase total
free RAM, but fragmented holes between suffix owners do not fit
one 010000 APR child. This is a feature-performance limitation,
not a proven allocator/compiler defect. It does not establish
equal-population net RAM or transient-peak savings: enabled B
and disabled sixth RUN are different child counts. A matched
five-child physical snapshot is the next meaningful comparison.
