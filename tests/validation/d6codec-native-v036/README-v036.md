# v036 — cursor-based full-history search

PDP-6 native encoder experiment derived from v031. Retains the complete
128-word backward match history, unchanged codec format and decoder.
Instead of recalculating `current - distance` for every candidate, a
candidate source pointer in AC14 starts at the oldest history word and
advances one word after each candidate. AC12 performs inner-loop word
address calculations without clobbering this rolling candidate pointer.
This needs no static RAM or hash table.

Five native regression tests PASS. Assembled code: encoder 127 words,
decoder 99 words, combined 226, static data/BSS zero. Baseline v031:
126+99=225 words.

Encoder-only step-limit measurements on identical 128-word sources:

| Workload | v031 baseline | v036 pointer cursor |
|---|---|---|
| deterministic distinct words | FAIL 50000, PASS 55000 | FAIL 44000, PASS 45000 |
| repeated nonzero word | FAIL 2000, PASS 2500 | PASS 2500 |

This is the first demonstrated improvement to the distinct-word exhaustive
search without sacrificing history or adding BSS: at least 5000 fewer steps
than the baseline's lower completion bound versus the candidate's upper
bound. The precise count and PDP-6 CPU cycles are not measured. The v036
candidate costs one additional 36-bit code word and should be retained
for further representative-workload validation and compression-size parity.
Native even-halfword match emission and production resumable ABI remain
outstanding. No DAIMOS/KCORE edits.
