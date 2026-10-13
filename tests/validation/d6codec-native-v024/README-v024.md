# Native codec v024: shared word/zero match emission

Research-only; no DAIMOS/KCORE changes. The v023 word-reference and zero-run
emission paths repeated the group control, descriptor packing, capacity,
input advance and output advance logic. Both now enter one `match_emit`
block with kind/distance in AC13 and length in AC6. All four v023 native
PDP-6 fixtures PASS with unmodified expected encoded output sizes.

DAS -F -C: v023 encoder 122 words, v024 encoder **110** words; decoder
remains 99 words. Combined executable code decreases from 221 to **209**
36-bit words, with zero .data/.bss in each codec object. Output token format
is unchanged. v024 remains a subset encoder: distance-one word matches,
zero runs and grouped literals, no multi-distance search or halfword search.

The corpus research in `tests/host/d6codec-v024` demonstrates that merely
extending this distance-one matcher without cost modeling is premature.
Further work should compare size and CPU cost for 8/32/128-word bounded
history searches before choosing a resident algorithm. No KCORE integration.
