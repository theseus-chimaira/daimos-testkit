# v042 — native encoder-only step bounds for grouped versus singleton streams

Research-only isolated PDP-6 benchmark using three 128-word real DAIMOS DXR
payload excerpts fixed in v041. The two native encoder implementations are
copied and independently symbol-versioned: v036 singleton token grouping,
127 36-bit code words; v041 mixed-token packing, 129 code words. Test files
call one encoder and return without decoding or stream comparison; the
existing native tests in v041 separately establish correctness and exact
parity against the host grouping policy. These v042 results therefore
isolate the encoder from the decoder and verification loops, but still
include the common small CRT entry/exit path.

| 128-word DXR excerpt | v041 grouped | v036 singleton |
|---|---|---|
| configctl | completes by 50,000 steps | completes by 50,000 steps |
| darc | FAIL at 30,000; PASS at 40,000 | FAIL at 40,000; PASS at 50,000 |
| d6lz | completes by 50,000 steps | completes by 50,000 steps |

Only `darc` has discriminating tested bounds; this is not a universal
speed claim. Step-limit failure means incomplete execution, not a codec
error. Simulator instruction-step bounds are not PDP-6 cycle counts or
measured wall-clock CPU time. Grouping needs +2 encoder code words, zero
static RAM and no standalone token buffer; previously measured v040 host
model projects 139,390 compressed words versus 151,853 with singleton
policy across 81 DXRs. The complete DXR native ratio is not yet measured.

Do not modify production DAIMOS/KCORE or concurrent shared testkit files.
