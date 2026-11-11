# v1498: real foreign TERM policy for nonresident DISK owner

The test extracts `proc_event_apply` unchanged from the production
PDP-6 `proc_pdp6.s`, and executes it with `p10run` on a real PDP-6
instruction interpreter. The controlled process descriptor has a
nonresident DISK VM; its u-area remains resident. The FILE-close and
process-finish helpers are test-controlled observers, not real device
drivers or VM teardown. No production source is changed.

Verified in order:

1. WAIT_CHILD preserves the owned kernel continuation, returns a
   deferred TERM and records the pending FD-control bit. No FILE
   or finalizer call occurs.
2. A repeated TERM coalesces without closing or finishing anything.
3. Clearing WAIT while saving an executive-mode PC still defers TERM.
4. Clearing prior pending bits, supplying a user-mode saved PC and no
   WAIT allows the real event handler to request foreign finalization.
   A refused VM teardown returns failure without releasing the DISK
   record or publishing TRANSITION/FINALIZE.
5. A later successful release is a distinct committed event; subsequent
   delivery to the quarantined transition owner is rejected.

An executable negative source mutation bypasses the saved-PC guard,
allowing an unsafe foreign teardown attempt. The test rejects it.

Run with `DAIMOS_REPO=$HOME/git/DAIMOS` and
`PDP10_PREFIX=$HOME/cross`:

```
sh tests/validation/daimos-backstore-term-classify-v1498.sh
```

Status: native positive and negative gates PASS. This proves the exact
current source decision rules but does not identify the predicate
that was exercised in the earlier physical v1495 guest. Physical
immediate-versus-deferred outcome still needs a per-event snapshot or
branch witness, plus final corrupt-backing acceptance. The historical
v883/v918/v925 tests carry obsolete assumptions about fatal-event
delivery and do not replace this new source-linked focused test.
