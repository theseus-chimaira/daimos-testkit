# D6FS bitmap-range injected write failure (2026-10-12 v1)

The isolated test-only backing dispatcher rejects logical writes within
487..525 (decimal), the allocation-map range on this particular generated
D6FS volume. This is image-layout dependent and must not be transplanted
without revalidating geometry. A native C99 test attempts to grow an empty
file by one word, requires an I/O error and the prior zero-word EOF after
reopening, and halts normally. The untouched production DAIMOS tree supplies
the generated assembly for the test build.

A live PDP-6 SIMH execution passed the injected allocation-map failure
probe and orderly HALT (2/2). `d6fsck -n 4` reported CLEAN, superblock
670 sequence 3, 179196 blocks and 360 FCBs. Unlike the previous single
logical 487 attempt, this did return the expected error while the test-only
injection was restricted to allocation-map blocks.

This is error-return and visible-EOF acceptance only. The harness has not
yet proved that a specific rejected bitmap write was attempted using a
write-attempt counter or trace. Ambiguous FCB writes, power cuts, and
crash-atomic HISTFILE commits remain open.
