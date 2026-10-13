# v029: rejected precheck optimization

The baseline `encode_v029.s` is the v028/v027 126-word encoder with versioned symbols.
The separate `encode_v029_candidate.s` tries an early comparison at the first
position beyond the current best word match before performing full candidate
extension. Its initial assembly passed, but PDP-6 round trips failed due to
incorrect comparison skip semantics and use of AC0 as an indirect index
(PDP-6 index register zero means no index). Both bugs were fixed in the
candidate, and five test fixtures then passed.

A test-only `encode_v029_instrumented.s` measures calls, candidate probes,
comparisons, and the extra prechecks. Native PDP-6 simulator results:

| Fixture | Baseline v028 calls/candidates/extra comparisons | Candidate v029 calls/candidates/extra comparisons/prechecks |
|---|---|---|
| Hidden match | 6 / 14 / 12 | 6 / 14 / 12 / 2 |
| Distinct literals | 9 / 36 / 0 | 11 / 55 / 0 / 0 |

The candidate is rejected: it adds instructions and preliminary comparisons
without improving these fixtures, and increases search calls/candidates on
the literal fixture. These are search events, not full instruction or cycle
counts. The baseline remains 126 code words, decoder 99, 225 total, zero
resident static data; the instrumented candidate allocates four BSS counters.

No production DAIMOS/KCORE files or shared testkit configuration modified.
