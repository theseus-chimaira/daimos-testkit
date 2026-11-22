# v1807 integrated 48K physical paired acceptance gate

Run `check-physical-pair-v1807.sh` with the retained evidence directory
from two **independent** `pure-runtime-reclaim-v1673` GENERAL and STRICT
guests. The wrapper requires both original A/B/C guest console witness
sets, both KCORE and KINIT maps, actual `INIT` fixture source-map
symbol, disk-SWAP inclusion only in GENERAL, and successful native
RUN/EXIT/WAIT.

The `test-pure-integration-pressure48-v1807` target sets
`KEEP_TEST=1` to preserve the expensive source-built physical
evidence required by the paired verifier.

The original `measure-v1673.py` creates each report from **actual
SIMH physical MM reads**, not a fabricated model. The paired comparator
uses the explicitly selected v1807 18,173-word resident footprint.
All original MM/mode/owner constraints remain intact; the historical
v1673 standalone comparator default remains 17,729 words.

The wrapper also reruns the full original physical MM/CTY negative
mutation suite independently against **both** actual guest logs.
No bitmap-mode3 or continuous 48K high-water acceptance is implied.

## Integrated physical result (2026-11-22)

The source-matched GENERAL and STRICT guests each completed A/B/C
with nine RAW PACKED suffix owners at B, a refused tenth RUN,
and nine clean EXIT/WAIT completions. Each reported 18,173 resident
words and the same original MM free sequence
26,997 -> 2,350 -> 26,997, with exact original owner cleanup.
The integrated paired comparator PASSed and the original six
MM/CTY negative controls were rejected on each of the two
independent captures (12 negative checks).

The first invocation of the new wrapper exposed broken shell argument
separators: the underlying paired oracle and negative controls passed,
but two wrapper predicates printed command errors and did not test
the intended independence checks. These separators were corrected
and the **entire wrapper rerun successfully with no command errors**.
An additional duplicate-transcript input was explicitly rejected.
The historic v1673 comparator still rejects this newer source's
18,173-word footprint unless the versioned integration profile
is explicitly selected. No default suppression was added.

Re-run with `V1807_PHYSICAL_EVIDENCE_DIR` pointing to the retained
two-guest directory and `DAIMOS_REPO` to the integration checkout:
`make test-pure-integration-verify48-v1807`. This is a read-only
verification gate: it does not create or alter the guest disk media.
