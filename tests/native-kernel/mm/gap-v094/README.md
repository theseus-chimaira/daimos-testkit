# Native PDP-6 MM gap/arena regression v094

The test links the production `mm_pdp6.s` directly through `p10run`,
not the host `mm.c` model or a stand-in search routine. It uses a fixed
fixture with two managed 4K-word arenas, each containing two occupied
1K-word extents. It asserts first LOW and highest HIGH placement,
alignment-induced fragmentation, total-vs-contiguous free classification,
and preservation of the extent-table size on failure. The same fixture
passes against the unoptimized v093 baseline and optimized v094 allocator.
Other native MM regression targets remain independently executable.
