# v106 Native PDP-6 relocation regression

Extends v105 multi-process, pinned-island, multi-arena compaction with an
explicit post-relocation check that the extent descriptor's **left-half
length remains 01000 octal words** after its right-half physical base is
updated. Executes production `mm_pdp6.s`, exact `vm_extent_move` and
`fs_move_words` assembler instructions through `p10run --machine pdp6`.

Result: PASS against v106 optimized MM. Runqueue and PI are instrumented
external fixtures rather than the complete operating system.
