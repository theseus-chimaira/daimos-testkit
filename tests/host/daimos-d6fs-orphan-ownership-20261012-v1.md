# D6FS orphan ownership — positive and negative tests (2026-10-12 v1)

Starts from the preserved CLEAN four-member PDP-6 SIMH disk image on which
FCB 0451 is a six-word regular file in root directory slot seven, owning
one extent spanning eight allocated blocks. Synthetic mutations use an
isolated compiled copy of production `d6fsck.c`, **only on cloned images**.

Positive case: clear just the six-word directory entry for 0451, preserving
its existing extent and allocation bits. Read-only `d6fsck` diagnoses the
unreachable FCB; `d6fsck -r` reclaims it, frees the blocks formerly owned
only by that FCB, fixes the allocation map, publishes a newer CLEAN
superblock, and verifies the repaired image. A second `-r` is idempotent.

Negative case: duplicate 0451's FCB into free slot 0452 while retaining the
original directory entry. Both FCBs now claim the same extent blocks.
Read-only `d6fsck` detects cross-linking; `d6fsck -r` refuses all repairs
with `ambiguous corruption remains; no repairs written`. Checksums of the
ambiguous clone are identical before and after the refused repair.

**Observed with both baseline and changed-block-only host d6fsck: PASS**.
The pristine input disks are checksum-verified unchanged. These are test-only
synthetic states, not evidence of safe journaling or recovery under arbitrary
power loss, and no kernel code is executed. Always validate actual durable
ownership before freeing any extent.

Run with `DAIMOS_REPO=/path/to/DAIMOS`,
`D6FS_CLEAN_DISK=/path/to/clean/disk`, and `TMPDIR=$HOME/tmp`.
