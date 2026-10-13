# v028 — native search-work instrumentation checkpoint

Experimental daimos-testkit-only measurement against the v027 bounded
128-word native matcher. The release-sized `encode_v028.s` is behaviorally
identical to v027 (126 36-bit text words), with only versioned symbols.
The `encode_v028_instrumented.s` test-only copy allocates three BSS words
and increments them at match-search entry, candidate-distance evaluation,
and subsequent word comparison. Do NOT use the instrumented copy as a
production decoder/encoder or include its BSS in resident-size claims.

All five v027 round-trip and error tests pass with the uninstrumented
encoder and v020-based 99-word decoder. PDP-6 simulator measurement on
`test_hidden_v028.s`: 6 search calls, 14 candidate-distance evaluations
(octal 016), 12 additional word comparisons (octal 014). The distinct
11-literal fixture gave 9 search calls (octal 011), 36 candidate probes
(octal 044), no further word comparisons. These counters measure selected
search-loop events, NOT full PDP-6 retired instructions or cycle times.

A 4-instruction lookahead guard for fewer than 3 remaining words was
implemented and exercised (130 encoder words), but it did not change the
hidden-match fixture counters and was rejected from the final encoder.
The smaller 126-word v027 algorithm is retained. More meaningful speed
work requires host/target instruction tracing or a higher-value match
candidate elimination heuristic; do not increase resident RAM for an
unproven speed gain. Production DAIMOS/KCORE untouched.
