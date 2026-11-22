# Physical source-replay negative gate v1815

The original v1682 48K STOP -> PACKED -> foreign TERM acceptance must
not be weakened by a text-only source witness. In addition to the
existing physical owner and saved-PC checks, `measure-v1682.py` now
requires exactly one `V1682 APR WORDS 3072` event in the original
console transcript. The producer emits it only after the native APR
growth observation. This is an additional source-authenticity check,
not a replacement for the v1673 A/B/C owner conservation oracle.

`test-negative-v1682.py` copies (never edits) the original physical
console evidence and creates five mutated controls:

1. Clear the saved USER-PC flag for the physically stopped process.
2. Forge an EXEC/wait bit in its actual scheduler word.
3. Replace the physically observed STOPPED scheduler state.
4. Remove the foreign TERM acceptance event.
5. Replace the APR growth witness with an incorrect size.

The program finds physical addresses from the source-linked fixture
and KCORE maps and mutates only a single word in the real B checkpoint
for the first three cases. Every mutation must fail the full original
measure wrapper, not merely a regular expression check.

Use the original preserved v1682 source artifacts for both profiles:

    V1815_EVIDENCE_ROOT="$TMPDIR/daimos-v1682-physical-stop-term-v2" \
      make test-pure-stop-foreign-negatives-v1815

`replay-negatives-v1815.sh` requires this evidence root explicitly.
It uses the shared v1673 fixture map and each profile's independent
KCORE map and original console transcript. It replays GENERAL and
STRICT original evidence successfully, then rejects five mutated
physical source controls in each profile. Recorded v1815 result:

    original GENERAL: PASS; five mutations rejected
    original STRICT: PASS; five mutations rejected

The run is an evidence REPLAY, not a new simulator execution or a new
K05-K09 acceptance milestone. The preserved historical data and dirty
worktree remain intact.
