# v724–v725: identify the blocked INIT's event producer

The clean v710 PDP-6 boot reaches INIT and then blocks slot 1 on
`proc_wait_event` (octal `013235`) with AC1 = `034745`.
The entry-state AC17 is `000135034746`; the stack at `034746` contains
`340000026271`, identifying the return PC `026271`.

The v725 native instruction dump shows:

```
26267: 201057000000   ; MOVEI 1,(17)
26270: 260740013235   ; PUSHJ 17,proc_wait_event
26271: 260740026340   ; PUSHJ 17,dsk_dispatch
```

This is the `dsk_runtime_wait` call sequence in `system/kernel/drivers/dsk_io.s`.
The wait address is the disk-request descriptor's completion event word on
the sleeping process's private stack, not a standalone pipe, generic
run-queue event, or filesystem-provider lock. `dsk_pi_idle` calls
`proc_wakeup_event` on `dsk_active_request`'s address plus two words;
`dsk_fail_runtime` also resolves the outstanding request on error.

**Confirmed:** INIT is sleeping on a disk-sector request completion.
**Not established:** whether the disk controller generated its completion
interrupt, whether the installed DSK PI handler was invoked, whether the
watchdog expired, or whether the event had been signalled before the snapshot.

The next targeted native trace should inspect `dsk_active_request`,
`storage_state`, disk PI invocation, completion-event writes and watchdog
ticks. Avoid changing scheduler selection logic based on an I/O wait.
