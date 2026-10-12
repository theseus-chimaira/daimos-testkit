# Ambiguous FCB fault control — 2026-10-12

This baseline uses the same preseeded `/CONFIG/FCBSEED` file and a normal
one-word append. The test-only backing dispatcher selects an unreachable
logical block (16777215), so no real metadata write should be rejected or
have its success converted to a failure.

The fixture requires a successful one-word write, reads back both words,
performs an orderly HALT, then runs read-only `d6fsck`. Live PDP-6 SIMH:
append/readback PASS, HALT PASS, `d6fsck` CLEAN, 179196 blocks, 368 FCBs,
selected superblock 670 seq 3.

The matching injected scenario targeting logical FCB block 479 reproduces
two unreachable FCBs (451, 452), whereas this baseline is clean. This
controls for a generic image/harness artifact. It does not yet identify
which target FCB is modified, or prove a single fault hit, nor simulate
power loss or actual storage durability. The discrepancy remains OPEN.
