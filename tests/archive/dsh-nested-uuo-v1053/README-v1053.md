# Historical DSH nested-UUO diagnostics (2026-11-03, v1053)

This directory preserves twelve untracked diagnostic probe files and
the locally modified `daimos-runtime-report.md` from the 2026-10-22
`testkit-dsh-nested-uuo-stress-20261022-v54` development worktree.
The files were copied unchanged; `SHA256SUMS-v1053.txt` records their
SHA-256 hashes, which were checked against the original worktree.

The probes include nested-process timeout reproductions, pipeline
follow-up tests, history/command lookup sequences, and progressive
prefixes designed to isolate invalid UUOs. The stored report records
35 passing commands in that historical run. Neither this report nor
the individual probe files demonstrate that all original nested-UUO
stress failures were resolved in current DAIMOS.

No archived probe is wired to default or release test targets.
Current testkit main already contains a media-isolation regression,
which was rerun and passed during consolidation. The historical
branch also contains angle-parameter lexer and EDCORE tests that
depend on source not integrated in current DAIMOS. Their original
commits are preserved in the versioned legacy testkit archive.

These are preserved artifacts and experiments, not new acceptance
claims. Full native guest validation is required before restoring
any historical probe to an active regression target. No 32K tests
were run during this consolidation.
