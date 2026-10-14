/* Standalone native tests lack KCORE's final linker boundary. The live
 * production symbol is zero-sized: only test fixtures allocate backing. */
.bss
.globl mm_extents
mm_extents: .block 0100
