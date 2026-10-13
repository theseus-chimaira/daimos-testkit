# v040 — isolate mixed-token group packing on the 81-DXR corpus

Host-side research model, based on `tests/host/d6codec-v039/compare-v039.py`.
The reference policy emits literal-only groups and singleton match/zero
control groups. This experiment instead makes a *token list* with the
same <=128-word history and matches, and packs at most 30 literal/match
tokens under one control word with two 18-bit descriptors per descriptor
word. Every packed stream is losslessly decoded back to all source words.

| 81 DXR payloads | compressed 36-bit words |
|---|---:|
| raw | 159973 |
| native singleton policy model (v039) | 151853 |
| packed mixed groups | 139390 |
| v006 host codec | 131548 |

Mixed groups recover 12,463 of the 20,305-word gap (~61.4%). The
remaining 7,842 words need investigation, including token selection,
match lengths and corpus-specific halfword patterns.

A technically important restriction: an even halfword distance of `2*d`
points to exactly the same source word as a word-reference distance `d`.
Thus, for the same maximum history and length semantics, searching kind-2
*even-distance* candidates cannot discover new words beyond ordinary word
back-references; this simple model confirms its aligned-even output equals
word-only output. This must NOT be interpreted as proof that native and host
v020 token choices or compression are equivalent. In particular the
previous v020 host codec's tokenization and descriptor length semantics
require precise source-level reconciliation before planning a native
halfword matcher. Odd-halfword matches are intentionally unsupported by
the 99-word profile decoder, and v040 does not add them.

This is a host policy model, NOT a PDP-6 assembler implementation. It
materializes tokens and therefore does not establish a viable low-RAM
streaming encoder. The next native design should try direct group
construction using the caller-provided destination buffer (no separate
scratch token array), preserving strict capacity checks and resumability.

No production DAIMOS/KCORE or shared testkit files changed.
