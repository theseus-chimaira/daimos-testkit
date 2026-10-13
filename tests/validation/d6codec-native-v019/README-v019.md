# Native PDP-6 decoder v019 — aligned and odd halfword distances

Standalone testkit-only experimental v006 counted-group decoder. No DAIMOS
or KCORE modifications. v018 word match/zero/literal decoder was 93 PDP-6
.text words. Adding even-offset halfword matches takes 99 words; supporting
odd-offset halfword reconstruction yields 117 words (DAS -F -C).

PASS on PDP-6 simulator:

* `run-v019.sh` checks kind-2 even-distance halfword match, equivalent to
  overlapping whole-word copying.
* `run-odd-v019.sh` checks kind-2 odd-distance halfword match at distance one,
  including overlapping halfword reads. The expected values are generated
  from the halfword recurrence; the first handwritten expected sequence was
  corrected during development.

The decoder preserves exact input/output bounds for currently supported
paths, but has only these small fixtures and lacks complete malformed-stream
coverage, native compatible compressor, resumable input, and kernel C ABI.
It clobbers AC10..AC16 and is not production-ready. Previous v018 tests must
be rerun against v019 in a future integrated test matrix.

The odd-halfword path uses an extra construction loop even though the
profiled production-like corpus rarely exercises it. Its resident code cost
should be scrutinized before integrating any universal format.
