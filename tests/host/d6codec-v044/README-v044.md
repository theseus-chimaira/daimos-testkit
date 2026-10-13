# v044 — isolate actual v006 match-selection policy on 81 DXRs

A reproducible host-only test in the existing paired 36-bit stream format.
The Python reference uses the actual `source_v006.c` algorithm as its basis:
word matches at least three words; zero-run >=2; 128-word history;
halfword matches at least four halfwords (two whole words); up to 127
output words per descriptor; and strict longer-than-best selection.
All 81 DXR images are loaded via the validated v039 loader. Each variant
uses the same 30-token paired-control packing and every output stream is
losslessly decoded and checked against the source, including odd-halfword
overlapping references. A host verifier halfword-offset bug was found and
fixed during the experiment; all variants then completed successfully.

Variant                           words      delta vs full v006
v006 word-only                    139470       +7922
v006 word + even halfword         131556          +8
v006 word + all halfword          131548           0

The native v041 grouped policy model was 139390, 80 words smaller than
v006 word-only because its zero-run and match tie choices differ. The
ablation establishes *within v006's own policy* that enabling the
even-halfword path reduces the corpus by 7914 words, while enabling odd
halfword offsets additionally reduces it by only 8 words. The earlier
claim that even-halfword matches were redundant was incorrect: even
halfword distances indeed point to the same words as word distances,
**but the v006 halfword path accepts two-word matches**, whereas the
normal word path requires three words. The newly accepted short matches
account for the substantial improvement.

Token counts (word, zero, kind-2 halfword, literals) are provided in the
results table. Threshold 1 versus 2 for zero-runs gives identical results,
because the v006 rule requires at least two zeros regardless. Searching
word distances in ascending versus descending order gives the same totals
for the tested corpus; that is not proof of stream identity.

The native decoder accepts even halfword distances; adding a 2-word
back-reference emission option with matched threshold may therefore
recover most savings without an additional native halfword scanner or
supporting odd-distance references. This is a design hypothesis requiring
native assembler size, correctness and speed measurements; no production
DAIMOS/KCORE changes are made here.
