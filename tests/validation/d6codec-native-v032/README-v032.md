# v032: no improvement from match-comparison address-register refactor

Research-only checkpoint based on accepted v031. A candidate inner-loop
refactor computes the target and history word address using AC12 rather
than modifying and restoring AC14, preserving the prior candidate origin.
The algorithm, maximum 128-word backward history, search order, emitted
stream format and output remain otherwise unchanged. It uses no new RAM
but saves no assembled instructions: encoder remains 126 36-bit text words,
decoder 99 words, combined 225 words, static data/BSS zero.

All five native PDP-6 regression fixtures passed. Encoder-only simulator
step-limit measurements on the same 128-word fixtures from v031:

| Workload | Incomplete at | Completed by |
|---|---:|---:|
| 128 deterministic distinct words | 50000 | 55000 |
| 128 identical nonzero words | 2000 | 2500 |

These bounds are **identical** to v031. No improvement in code size or
execution was demonstrated, so this candidate is rejected as an
optimization. Exact instruction counts (and machine cycles) remain to be
measured. A promising next direction is reducing duplicate lookahead
searches through token-local cached results or a compact candidate index,
but both need explicit RAM and correctness accounting first.

The v020 host corpus continues to establish the compressed-size target;
this register-only change is not a new compression algorithm and therefore
no new corpus compression claim is made.

No DAIMOS/KCORE/shared testkit files were modified.
