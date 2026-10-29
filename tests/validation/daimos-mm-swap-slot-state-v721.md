# v720-v721: actual scheduler slot state at first idle period

The v720 trace breaks at `proc_runq_remove` (`010575`), resumes, and
then breaks at the real idle loop (`014102`). Run-queue head is zero.

**Correction to v719:** `proc_table` at `020604` contains a *pointer*,
octal `034060`, rather than the process descriptors themselves. The
v719 memory dump of `020604-020616` was KCORE pointer/control storage.
v721 explicitly inspects the actual three-word process descriptors at
`034060-034070` in the same v710 linked image.

Slot 1 occupies `034063-034065`:

```
034063: 034521400001
034064: 010000766000
034065: 320024034745
```

Scheduling LH is `320024`: the state field is octal `3` (SLEEP), and
the wait-class field contains `020000` (EVENT). Its RH wait channel is
octal `034745`. An empty runnable queue is expected while the only live
process is waiting for an event. `proc_high_slot` equals octal `2`.

This is not yet proof of a missed wakeup. Next determine what object owns
event word `034745`, whether the event can become ready, and whether its
producer calls `proc_wakeup_event` with the same address. The diagnostic
copies clean media and makes no production code changes.
