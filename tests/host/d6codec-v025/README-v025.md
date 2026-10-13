# v025 — bounded match-search windows on the 81 DXR-image corpus

Research-only C99 copies of the previously validated v020 even-halfword
encoder, with word history and even-halfword history limited to W=8,32,128
words. These are **host** two-stage encoders (with temporary allocations),
not native PDP-6 assembler or kernel-ready memory bounds. All 81 DXR images
are sourced from the v006 recorded path list and are decoded byte-for-byte
with the matching window codec for lossless verification.

| window (words) | source words | compressed words | delta vs v006 |
|---|---:|---:|---:|
| 8 | 159973 | 159601 | +28053 |
| 32 | 159973 | 148212 | +16664 |
| 128 | 159973 | 131556 | +8 |

Original unrestricted v006 result: 131548 compressed words. The 128-word
variant matches the prior v020 even-only result. Each smaller window limits
both word and aligned-halfword search range, so the effect cannot be
attributed exclusively to the word match candidate limit.

Exploratory wall-clock host runs (one process over all 81 images, three runs):

| window | elapsed seconds |
|---|---|
| 8 | 0.1198, 0.1197, 0.1198 |
| 32 | 0.1314, 0.1332, 0.1319 |
| 128 | 0.1687, 0.1677, 0.1672 |

Host timings are noisy and do **not** estimate PDP-6 cycles. They also
include loading and encoding/decoding. No PDP-6 native assembler footprint
was produced in this checkpoint, therefore no net KCORE RAM conclusion is
justified. The next experiment should code a 128-word native history scan,
measure its .text words and native instruction count, and check whether its
CPU cost is acceptable. Explicit CPU limits may justify a faster matching
algorithm instead of artificially shortening useful history.

No source in DAIMOS or production KCORE was changed.
