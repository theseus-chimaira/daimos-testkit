# v043: tightened native grouped-vs-singleton step bounds

Reproducible 30-case PDP-6 simulator step-limit sweep of encoder-only
128-word excerpts originally extracted from three actual DAIMOS DXRs.
The script uses the established v042 fixture/encoder pairs, with no
production code modifications. It varies the simulator maximum from
35,000 to 55,000 instructions in 5,000-step increments, recording
`result=PASS` or `result=FAIL` from the generated reports. A FAIL here
means a step-limit timeout/incomplete execution, not incorrect encoding.

| DXR excerpt | grouped v041 | singleton v036 |
|---|---|---|
| configctl | >35,000 and <=40,000 steps | >45,000 and <=50,000 steps |
| darc | >35,000 and <=40,000 steps | >40,000 and <=45,000 steps |
| d6lz | >40,000 and <=45,000 steps | >40,000 and <=45,000 steps |

Native grouped output was independently verified against the grouped host
model in v041. This timing experiment runs the encoder only with common
CRT overhead; do not infer exact instruction counts or PDP-6 cycles.

Key codec policy differences that still need quantified **apples-to-apples**
comparison with v006: (1) zero-run threshold and preference, (2) word-match
versus zero-run tie resolution and the group boundary token policy, (3)
actual host stream format and any halfword-offset restrictions. The
`d6codec-v025/source_window_128_v025.c` encoder is a DIFFERENT older
36-token / full-word-descriptor stream from the paired v006 format and
must not be used as a direct source of v006 savings attribution. The v040
'half_mode' variable is a no-op comparison, not an empirical isolation of
halfword search. A lossless native full-DXR run is still outstanding.

Native static code: 129-word grouped encoder and 99-word decoder, zero
.data/.bss; +2 encoder instructions relative to v036 singleton policy.
All experimental work is isolated in the testkit, away from DAIMOS/KCORE.
