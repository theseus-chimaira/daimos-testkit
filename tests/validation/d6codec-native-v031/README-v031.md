# v031 — encoder-only PDP-6 step-limit bounds

The accepted 126-word v030 encoder is copied, unchanged except for symbol
versioning. Two 128-word test fixtures directly call the encoder and return
without decoding or comparing output. This isolates the compressor from the
99-word decoder and 128-word output verification loop. The PDP-6 test CRT,
call/return, and success bookkeeping remain part of measured step limits.

| Source pattern | FAIL at step limit | PASS by step limit |
|---|---:|---:|
| 128 deterministic pseudorandom 36-bit source words | 50000 | 55000 |
| 128 identical nonzero source words | 2000 | 2500 |

The distinct-word workload costs over 20 times as many *end-to-end* steps
as the repeated workload. These are bounds, not exact encoder instructions
or PDP-6 cycles. A failed low step limit signifies incomplete execution,
not a codec error. Earlier go-mode versions of the fixtures were validated
with a 192-word compressed-output buffer and exact decoder round trips.

The research encoder uses a full 128-word backward candidate search at each
literal lookahead. Profiling should now prioritize fast reduction of redundant
candidate scans on incompressible source without losing 128-word history.
No DAIMOS/KCORE/shared testkit files are modified.
