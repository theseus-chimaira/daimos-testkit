# v104 — Repeated PDP-6 MM compaction regression

Runs production `mm_pdp6.s`, `vm_extent_move`, and resident word-copy
assembler using `p10run --machine pdp6`. Adds a repeated cross-arena
compaction request: the second call must not change descriptor count,
relocated base, or PI disable count. Existing 512-word payload, pinned,
u-area/runqueue and rejection tests remain.

The synthetic process record and u-area were moved to octal 06000/07000
to remain disjoint from growing test image BSS. This fixture relocation
is necessary to avoid writes into resident allocator descriptors.

The test does not yet model multiple successfully relocated processes or
production scheduler/PI concurrency.
