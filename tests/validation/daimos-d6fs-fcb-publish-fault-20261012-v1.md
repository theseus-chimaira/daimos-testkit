# D6FS FCB publication rejection, PDP-6 SIMH (2026-10-12 v1)

A test-only backing dispatcher rejects writes to the FCB block range
442..486 (decimal), identified from a checked D6FS image with FCB_START=442,
FCB_BLOCKS=45. The isolated mkd6fs image pre-seeds `/CONFIG/FCBSEED` with
one 36-bit word. This avoids runtime file creation before exercising append.
The C99 fixture attempts a one-word append, requires a failure return,
reopens the file, and confirms precisely its original one word is readable.
The normal payload write occurs before the final FCB publication attempt.

Live SIMH: both probes PASS, orderly HALT PASS, and `d6fsck` reports CLEAN
(superblock 670, sequence 3, 179196 blocks, 368 FCBs). The injected
failure applies to FCB-table writes, so the result supports old-EOF
preservation on a rejected FCB update. The test still lacks an independent
write-hit counter, and a write rejected *before* backing durability does not
simulate a partially durable or ambiguous FCB commit. Power cuts, COW record
commit, and concurrent HISTFILE writers remain open.

The fixture's FCB block range is image-specific and must be rediscovered
for other media layouts; never apply this injector to production images.
