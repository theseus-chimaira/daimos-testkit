# Executable reservation private-stack lifetime, v1937

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-stack-lifetime-v1937

The native PDP-6 gate links the real stack-reservation address scanner,
process finalization, RUN discard, u-area release, foreign fatal event
and nonreturning owner EXIT. Eight cases cover a reservation behind an
unrelated head, an extent-boundary overlap, ordinary and marked EXIT
refusal, discard refusal, typed BUSY before MM release, foreign HUP
deferral, successful release with an unrelated reservation still live,
and fail-stop before a self-EXIT stack switch. Six unsafe variants
remove one guard or truncate the list scan; each fails an executed
native assertion. Destructive callbacks are controlled in this gate.

The extended v956 oracle executes actual MM deletion and verifies
reservation BUSY with zero MM pins, unchanged exact owner and successful
retry. v1097 typed refusal/unsafe controls, v869 FILE/finalizer guard,
v1086 normal stack handoff and v1933-v1936 loader/transaction/namespace
regressions pass. Older v869 extraction/parent fixture linkage was
updated for the current parent-waitability leaf. The historical v925
fixture has stale linkage and lifecycle expectations and was not counted
as a passing regression. Other historical extractors have not all been
adapted or rerun.

This establishes the explicit teardown barrier, not whole-guest fatal
PI6 scheduling acceptance. Self-EXIT with a live reservation deliberately
fails stop: it cannot legally abandon the continuation or silently
remove a dependency. No per-process storage or additional MM pin.
