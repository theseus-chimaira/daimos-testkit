# v046 — complete DXR payload comparison for v045 native policy

Independent Python host-side model of the native v045 grouped encoder:
128-word rolling-history search, accepting two-word matches, zero-runs,
and packing up to 30 tokens into paired 18-bit descriptor control groups.
Runs over all 81 DAIMOS-built DXR payloads listed in the v006 manifest.
Each output is fully decoded and checked against its 36-bit source words.
The reference uses the validated v044 v006-compatible even-halfword policy
with the same group format, but a different token-selection strategy.

| 81 DXR images | compressed words |
|---|---:|
| Uncompressed raw payloads | 159973 |
| v006 even-halfword policy | 131556 |
| v045 native two-word policy model | 131463 |

Thus v045's host model is 93 words smaller than v006 even-only across the
corpus, saving 28510 words against raw. This is not a measured full-native
PDP-6 encoding run. The established all-halfword v006 reference is 131548,
85 words larger than v045's model. Differences arise from token selection,
zero-run preference and tie policies; no causal breakdown is claimed here.

The standalone v046 native PDP-6 fixture covers the first 256 data words of
DAIMOS `darc.dxr`. Native compressed output is exactly 192 words, compared
word-by-word with this independent host policy model, and native decoder
reconstruction exactly matches all 256 original words. The source and
expected output are stored in the fixture, so the native test is self-contained.

The native encoder remains 129 text words, decoder 99, static codec RAM zero.
No DAIMOS/KCORE or shared testkit files were modified.
