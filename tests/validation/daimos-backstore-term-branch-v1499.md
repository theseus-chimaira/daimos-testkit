# v1499: physical slot-0 TERM decision witnesses (diagnostic)

`daimos-backstore-term-branch-v1499.sh` derives a fresh disposable
256K PDP-6/KCC F07 guest from v1495's one-bit checked-release refusal
injection. It preserves the production kernel checkout and original
strict, nonfault F07 acceptance checks.

The two failed swap-in service calls are instrumented immediately
before and after **real** `proc_event_apply` execution. At most two
events have separate storage for the selected process's descriptor,
VM, scheduling word, saved PC, pending FD-control bits, finalizer
marker and exact event return value. Scoped stage counters distinguish
foreign-event entry, deferred TERM, busy/rejected delivery, direct
finalizer entry, PREVM release refusal, and FILE close refusal.

Counters and snapshots exist only in the copied guest's fixed BSS;
they are absent from production KCORE. The observer uses AC4..AC7
outside the event's AC1/AC2 API, and `AOS`/`SKIPN` guards only within
the event path. No on-disk payload, owner record, bitmap release
decision or scheduler failure dispatch is modified.

To run:

```
DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross \
    sh tests/validation/daimos-backstore-term-branch-v1499.sh
```

`V1499_PREPARE_ONLY=1` prepares and shell-validates the derived runner.
The instrumentation and anchor self-checks can also be exercised on
a disposable copy of `system/kernel` without launching a simulator.
The physical report requires a completed HALT/EXIT and an exact,
unique map-backed memory value for each field, with two event
snapshots and no index overflow. It is diagnostic-only: no success
message from this report qualifies the full corrupt-BACKSTORE gate.

The v1495 physical run showed two real TERM calls but no immediate
PREVM, without proving the deciding branch. Native v1498 establishes
the correct production policy for WAIT, saved executive PC, refused
release and committed finalization. This physical diagnostic is
intended to determine **which** policy branch ran in the real guest.
