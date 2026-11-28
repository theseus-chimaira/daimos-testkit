# KGEN to KOPT wide expansion regression, v63a

Run with a v62j baseline checkout or git archive and the candidate KCC
source. No target installation or native self-build is required:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    KCC_BASE_SOURCE=/path/to/v62j KCC_SOURCE=$HOME/git/kcc \
        python3 tests/validation/kcc-kopt-wide-v63a/run-v63a.py

The test builds host-executable versions of the actual native phase
drivers. For every baseline translation unit and the wide-expression
fixture, KGEN consumes the same KIR2 input in both revisions. Matching
KOPT outputs must be byte-identical in both optimization modes.

The wire-level test compares all 16 signed/unsigned, resident/stack,
relational-condition combinations against v62j raw-text replay. It also
checks malformed wide descriptors, truncated records and rejection of
mixed KPCODE3/KPCODE4 producer/consumer pairs.

The source corpus does not necessarily trigger stack comparison
expansion; the direct record cases exercise it independently.
This is a hosted compiler-phase test, not native guest execution.
Evidence is retained in a uniquely named TMPDIR directory.
