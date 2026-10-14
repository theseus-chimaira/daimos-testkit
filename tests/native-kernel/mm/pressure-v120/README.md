# Native PDP-6 MM successful reclaim and descriptor pressure v120

Runs real `mm_pdp6.s` with instrumented external reclaim services.
`fs_memory_reclaim` can release a real MM extent via `mm_free`; the next
ordinary allocation attempt then succeeds at that base, with no swap
callback and consistent descriptors. Preserves v119 bounded NOMEM and
no-reclaim-callback checks.

A further case initializes all 32 descriptor slots with sorted one-word
extents and confirms a request with adequate physical space returns
MM_ERR_DESCRIPTORS, preserves the output and extent count, and performs
exactly two FS and one swap callback on the existing bounded retry policy.

The test does not link the real FS or process swapping reclaimer, and does
not imply full-system boot or concurrency acceptance.
