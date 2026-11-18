# v1660: bounded native PDP-6 bitmap FULL decoder preflight

Parent v1659 DAIMOS `ad64849f1bc6c416905533c0e90f2409616f4552`.
Run `DAIMOS_REPO=/path/to/DAIMOS PDP10_PREFIX=$HOME/cross
TMPDIR=$HOME/tmp sh tests/validation/pure-bitmap-decode-v1660/run-v1660.sh`.

The runner first runs the entire v1659 bitmap and actual MM allocator
baseline. It compiles the new actual DAIMOS C89 decoder with KCC and
links it against the original 30-word v1451 bitmap assembler on PDP-6.
The native fixture builds a 73-word image with three literals in
different mask groups. The exact stream is six 36-bit words.

The decoder must validate all bitmap control words, exact encoded
length, nonzero literals, partial last-mask padding, disjoint input
and output geometry before invoking the unchecked original decoder.
Negative tests confirm that no destination word changes on failure.
An independently compiled and executed mutant removes the exact
stream-consumption check and must fail the native test oracle.

`V1660_SKIP_BASELINE=1` is available for quick iterative testing,
but must not be set for release evidence. This helper does not
verify MM descriptors, publish mode3, change fixed KCORE or reclaim
RAW. Physical 48K/64K compressed-process acceptance remains open.
