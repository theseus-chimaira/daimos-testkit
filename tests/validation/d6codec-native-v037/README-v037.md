# v037: binary-exact parity of original and rolling-cursor native encoders

Both the 126-word v031 baseline and the 127-word v036 cursor matcher are
linked into a single PDP-6 test. Internal labels are given disjoint names.
Each test compresses the same 128-word source with both implementations,
compares encoded word counts and every encoded 36-bit output word, and
returns nonzero upon any mismatch.

Four explicit patterns PASS on PDP-6: deterministic distinct pseudorandom
words, a 17-word periodic pattern, all-identical words, and mixed sequential
and pseudorandom words. Thus the cursor version preserves binary-exact
output for these cases, including order-sensitive match selection.
The broader DXR corpus has NOT been run with either native encoder.

Encoder-only step-mode comparison (includes test CRT and return bookkeeping):

| Pattern | v031 baseline | v036 cursor |
|---|---|---|
| mixed (128 words) | FAIL at 25000 | FAIL at 25000 |
| period17 (128 words) | PASS at 12000 | PASS at 12000 |

These coarse bounds do not establish relative performance on these
patterns; the earlier distinct-input test still provides the direct
speed evidence (v031 fails 50000, passes 55000; v036 fails 44000,
passes 45000). Exact instruction/cycle counts remain unmeasured.

No static codec RAM, no changes to DAIMOS/KCORE, and concurrent uncommitted
changes are preserved. Further work: tighter step bounds for mixed input,
and a native word-exact representative DXR source fixture.
