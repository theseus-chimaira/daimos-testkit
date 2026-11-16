# P1-E v1633: 48K fixed-parent APR corridor capacity lower bound

The original v1631 physical experiment established that PURE on
rejects a sixth child while source-identical PURE off admits it.
The source-matched v1632 five-child MM snapshots measure +931
decimal physical free words with PURE enabled (including the
1758-word removable module), but less contiguous APR memory.

This testkit diagnostic reads the exact original v1629 PURE-on B
MM table and v1632 PURE-off five-ready MM table, cross-checks the
byte-identical linked KCORE/INIT images, and computes the physical
APR corridor between the last necessary low-core KERNEL_DYNAMIC
extent and the still-resident parent VM. No production guest,
kernel, MM owner table, simulator memory or source is modified.

    PURE_ON_CASE_V1633=/path/to/v1629/guest \
    PURE_OFF_CASE_V1633=/path/to/v1631/off/guest \
    PURE_ON_TRACE_V1633=/path/to/v1629/MM/trace.clean \
    PURE_OFF_TRACE_V1633=/path/to/v1632/MM/trace.clean \
        sh tests/diagnostics/pure-apr-corridor-v1633/run-audit-v1633.sh

Original physical geometry (octal PDP-6 words):

| Original boundary | PURE enabled | PURE disabled |
|---|---:|---:|
| Lowest nonmovable dynamic-core end | 046605 | 043247 |
| First APR-aligned free start beyond it | 050000 | 044000 |
| Resident parent APR | 126000..136000 | 126000..136000 |
| Full 010000-word APR slots below parent | 5 | 6 |
| Upper arena tail | 136000..140000 | 136000..140000 |

The tail after the parent is only 02000 octal, not enough for a
complete 010000 APR. Thus, if the parent and existing dynamic
objects are retained at these physical addresses, six additional
fully runnable children require the low-core dynamic region to
end at or below **046000**. At its measured end of 046605, PURE
enabled misses that boundary by **0605 octal / 389 decimal words**.
The dynamic-end shift from PURE disabled is exactly 03336 octal,
the installed 1758-decimal-word PURE MRES package size.

Five original PACKED suffixes have distinct 001000-octal free
prefix gaps and meet the 02000-octal aligned in-place restoration
condition. Moving just the suffixes can create a sixth RUN gap,
but it cannot create room for SIX simultaneous, complete APRs
below the fixed parent: six require 060000 octal words, whereas
only 057173 lie between the present dynamic end and parent.
That is a *capacity and restoration-liveness* constraint, not
an MM allocator correctness bug; PACKED suffixes are not movable
by the existing mm_compact backend and their placement is owned.

Reducing necessary low-core occupancy by at least 389 decimal
words (for example through a genuinely smaller PURE MRES with
otherwise unchanged allocations) is a **testable candidate**, not
a proven repair. It could leave a valid aligned 046000..056000
APR allocation while preserving each original child's free
001000-prefix restoration gap. Such a candidate MUST be built,
measured and physically tested: changing module size may affect
additional placement, and no production changes are made here.

The native auditor rejects forged changes to the last low-core
dynamic extent and the full parent APR descriptor. It does not
claim global impossibility after moving the parent, changing MM
representation or releasing otherwise necessary dynamic objects.

Still open: prove a safe capacity improvement in a real image,
test forced v1391 full/relocated restoration, physical failure
rollback, source lifetime, concurrent PI6 and matched temporal
peak RAM. PURE default OFF and strict 32K optimization HOLD.
