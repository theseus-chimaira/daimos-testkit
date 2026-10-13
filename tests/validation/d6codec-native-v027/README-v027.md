# v027 — shared 128-word search during literal lookahead

Experimental standalone PDP-6 encoder, isolated inside daimos-testkit.
The v026 encoder could find a 128-word-distance match only at a group
boundary, but stopped a literal group only for distance-one runs. v027
calls the SAME bounded 128-word word-matcher while scanning possible
literals. Search input cursor and remaining length plus group counters are
saved on the caller's existing PDP-6 pushdown stack and restored afterward.
No static data/BSS or heap token buffer is required.

DAS code size: 126 words encoder (v026: 123), 99 words decoder,
**225 combined**. The additional three code words do not measure
increased execution cost: repeated full-window searches may dominate
on the approximately 0.25-MIPS PDP-6. Native cycle measurement and
search reduction are still essential.

`run-all-v027.sh` executes five separate PDP-6 simulator fixtures:
* `test_v027.s`: explicit nontrivial-distance word reference and exact output
* `test_hidden_v027.s`: four leading literals followed by a 7-word match
  at distance four; the exact packed descriptor `07004,,0` is asserted
* distinct literal-group round trip
* 127-word zero-run boundary round trip
* insufficient destination capacity error

All five PASS. This remains only a prototype: no native even-halfword
match finder, streaming refill, production kernel ABI, native cycle
measurements or broad malformed/fuzz matrix. The 128-word search can be
CPU-expensive even though it is bounded. No DAIMOS or KCORE edits.
