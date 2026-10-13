# v041: native mixed-token grouping without a scratch token array

Research-only PDP-6 assembler encoder using the v036 128-word rolling cursor
match finder. At a group boundary, it writes a control-word placeholder into
the caller-supplied output. It then accumulates up to 30 tokens. Each new
literal appends to the output; every new descriptor is inserted ahead of
existing literals by shifting only that group's literal words in-place.
The second descriptor shares the existing descriptor word's right half.
The final control word contains token count and flags. No separate token
array, heap, global encoder state, or static working RAM is allocated.
The output buffer itself is the only token staging storage.

DAS: encoder **129 36-bit text words**; even-halfword-capable v020-profile
decoder **99 text words**; combined **228 code words**, zero codec data/BSS.
The v036 singleton-match encoder uses 127 words; v041 thus costs +2 words
for this grouped-stream capability. These sizes exclude test fixtures and
CRT and do not imply that the codec is production ABI-compatible.

PDP-6 simulator tests: ordinary mixed-token decode round trip, a hidden
match following literals, literal-only grouping, zero-run 127 boundary,
insufficient output capacity, plus three 128-word excerpts from actual
DAIMOS DXR payloads. On the DXR excerpts the native stream exactly matches
the v040 grouping model, including every 36-bit control/descriptor/literal
word: configctl 99 words, darc 79, d6lz 117. Exact-output-size capacity
(99 words) succeeds; capacity 98 words is rejected. All tests PASS.

A first implementation failed decoding due to the PDP-10 `LSH`
operating on a fixed immediate EA when a register-derived shift was
intended. The correct dynamic form `LSH 0,0(12)` uses AC12 for the
negative token-number shift when setting the flags bitmap. The bug was
corrected and both native and external model comparisons were rerun.

Limits: full 81-DXR model ratio 139390 words is a *host estimate*, not a
complete native run. Native end-to-end speed, proper kernel C ABI,
resumable streaming output and malformed-input testing are outstanding.
Odd halfword matching is unsupported by the intended decoder profile.
No production DAIMOS/KCORE modifications were made.
