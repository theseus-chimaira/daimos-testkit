# PDP-6 v020 aligned-only halfword decoder

Research-only, completely separate from ongoing DAIMOS/KCORE work.
The v019 decoder was 117 PDP-6 36-bit instruction words including odd
halfword offset handling. Removing that 18-word reconstruction loop and
rejecting kind-2 odd-distance descriptors yields 99 instruction words.
No data or BSS allocated by the decoder.

`run-v020.sh` executes three separate native PDP-6 deposit tests:
* aligned kind-2 halfword matching (round-trip fixture)
* odd-distance kind-2 match rejected with an error
* existing v018 multi-group, overlapping word-reference, zero-run,
  zero-length descriptor and truncated-stream checks

All three tests PASS. These do not constitute a complete malformed-stream
matrix. The decoder is not resumable and retains experimental register
conventions; there is no production kernel ABI adapter or compatible native
compressor. No production change is authorized by this result.

The host 81-image compression comparison under tests/host/d6codec-v020
measured a penalty of just 8 compressed words for the even-only restriction.
The joint result strongly favors eliminating odd-halfword decoder code,
subject to broader correctness tests and total RAM-budget measurements.
