# v051 — resident KCORE encoder+decoder stack baseline

Both encoder and decoder are mandatory kernel-resident components. The
baseline total is 129+99=228 text words, zero static data/BSS; do not
assume the encoder is user-space only. No production code is changed here.

A purpose-built native PDP-6 CRT fills its 512-word stack with a 36-bit
canary, then calls a complete real `darc.dxr` native encoding/exact stream
comparison/decoding test (2762 input, 2247 compressed words). On return,
it scans from the *top* of the stack down to the highest modified word.
The full test passes and records **6 stack words high-water**, including
CRT's initial PUSHJ main and the inner encoder search calls. The canary
scan is performed after main returns, not during an active call. The
original forward-scan implementation was rejected because it reports
only the first changed word (zero) rather than the high-water mark.

This is **not yet a proved maximum**: test other representative workloads,
error paths, wrapper ABI and memory bounds before production integration.
The kernel must carry both codec halves plus validated interface code,
actual stack and any caller-owned compressed/decompressed buffers.

Reproduction: run `run-v051.sh`, inspect `__v051_first_changed` in the
simulator report as an **octal** integer (observed 000000000006).
