# K11 v1977: bidirectional mask-directory codec

Run against the source checkout and installed KCC/DAS/DLINK/p10run:

    DAIMOS_REPO=$HOME/git/DAIMOS sh tests/validation/pure-bitmap-directory-v1977/run-v1977.sh

The production source is staged, not installed. Native PDP6 and KA10
execute the same C frontend and 36-bit assembler walker. Independent
canonical construction and per-word consumed-input ledger cover nine RAW
lengths (1,2,35,36,37,71,72,73,109), eight density distributions, eleven
signed offsets plus exact end alignment and both directions. Every encode
also runs the read-only planner; full-arena comparisons cover all writes
and all ordinary refusals, not only destination words. Diagnostics include
reverse-only success and both-direction refusal counts. Large 5248-word
zero/sparse fixtures exercise 146 masks, in-place expansion, excess output
capacity, cross-direction format identity, exact data and guard words.
These are synthetic large inputs, not captured DSH memory.

Four deliberately unsafe walker variants must execute and fail: no RAW
unread guard, no decoder mask guard, no decoder literal guard, no exact
consumption check. The separate late-error fixture injects a failure after
real writes and requires the hard WRITE_FAULT status, not normal refusal.
The caller still needs an exclusive MM lease and a recoverable ownership
transaction; the fixture is not a proof of failure-atomic MM commit.
