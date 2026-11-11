# v1502: correct scoped diagnostic counter polarity

The first v1499 full physical guest emitted two independent pre/post
TERM-owner snapshots. Those snapshots are valid; however the optional
branch counters were intended to be scoped to the two scheduler TERM
calls and used `SKIPN daimos_v1499_active` before `AOS counter`.
On PDP-6, that is the opposite of the intended condition: it counts
while the active marker is zero, and skips counting while nonzero.
The physical v1499 `foreign=023` and `deferred=023` are therefore
**not** event-scoped counts and must not be used as acceptance.

The corrected diagnostic uses `SKIPE daimos_v1499_active`, which skips
the increment while inactive. The new executable v1502 test
generates a disposable copy of the v1499 patched kernel, extracts
the **actual** two-instruction counter guard, and runs it on the
PDP-6 with inactive, active, inactive values. It must count precisely
one increment. The original inverted `SKIPN` mutation is rejected.

Run:

```
DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross \
    sh tests/validation/daimos-branch-guard-v1502.sh
```

Both positive and negative native gates PASS. This is a disposable
testkit instrumentation fix, not a production KCORE correction. The
first v1499 guest's before/after snapshots were captured outside
the faulty conditional and remain independent evidence. Recheck
corrected scoped counters only in a newly built physical guest.
