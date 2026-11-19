# P1-E v1635: physical origin of the parent APR placement loss

This is a read-only simulator replay of the **original v1629**
PURE-enabled source-built 48K PDP-6 no-AUX/TSFS guest. A breakpoint
at the linked original `vm_space_create` entry, PC 022472 octal,
captures the MM extents BEFORE process slot 1's initial VM exists.
The guest and physical tape copies remain unchanged.

    PURE_PARENT_BUILD_V1635=/path/to/v1629/build \
        sh tests/diagnostics/pure-parent-placement-v1635/replay-v1635.sh

The original machine shows current slot zero, high slot two, first
VM owner slot one, requested logical 007067 words (rounded to
010000 APR-aligned words), and three managed arenas. The highest
arena ends at 140000 octal. At that precise moment an already-
allocated `0201`-word unpinned `MM_TYPE_KERNEL_DYNAMIC` owner 6
occupies **137577..140000**, matching the source-backed BCACHE
private tag + 0200-word clean data slab. `bcache_pdp6.s` explicitly
asks for `MM_ALLOC_HIGH` when acquiring this slab.

The highest legal 010000-word APR under this cache owner begins
at 126000; without the obstructing top slab, the same source/MM
alignment rules would permit the first parent APR at 130000.
The fully independent original completed v1629 MM B snapshot
actually confirms that parent 1 was placed at **126000..136000**.
Thus the BCACHE slab's high preference is the physical direct
reason for losing one 02000 alignment interval above the parent.

    DAIMOS_REPO=/path/to/original/DAIMOS \
    PURE_PARENT_BUILD_V1635=/path/to/v1629/build \
    PURE_PARENT_TRACE_V1635=/path/to/v1635/trace.clean \
    PURE_PACKED_TRACE_V1635=/path/to/v1629/MM/trace.clean \
        sh tests/diagnostics/pure-parent-placement-v1635/run-audit-v1635.sh

The auditor source-authenticates BCACHE owner, size, high-placement
instruction, linked VM address, the actual extents before VM
creation and the later parent owner. It rejects a forged high
BCACHE owner and a forged 0200-word slab length.

**No allocator or cache code changes belong to v1635.** A coherent
candidate is to place the small, reclaimable BCACHE slab with
other low-core kernel-dynamic allocations, preserving MM ownership
and the full 0201-word cache. This could leave a complete top APR
for the long-lived parent, avoiding the fixed-parent 389-word
size requirement shown in v1633. Such a policy change MUST be
validated physically on 48K, against PURE-OFF and on the other
boot profiles. The first-VM snapshot alone does not prove the
candidate will admit six children or that all will restore.

Default PURE remains OFF; no entire-KCORE 32K size pass until P1-E
final feature acceptance.
