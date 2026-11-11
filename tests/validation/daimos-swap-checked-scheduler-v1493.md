# v1493: scheduler response to refused BACKSTORE release

Scope: real source-linked PDP-6 `proc_swap_in`, `proc_swap_mres_service_v481`,
`backstore_verify_allocated_v795` and `backstore_free`, with test-only MM,
physical disk read and event observer. No production kernel source change.

The fixture uses the established v1405 DISK owner and intentionally
incomplete 36-bit allocation bitmap. A real physical payload read succeeds;
the checked free rejects the corrupt run, and the newly allocated APR
extent is rolled back without losing the original disk owner.

The production slot-0 service receives the negative result and requests
exactly one `SYS_EVENT_TERM` for slot 2. It does not return positive
`MM_ERR_NOMEM` pressure, try an exchange, set cooldown, publish a
RESIDENT owner or set `PROC_SCHED_READY_ONCE`.

The native fixture checks process metadata, TRANSITION, MM rollback,
the original DISK record, bitmap, BACKSTORE and process-swap usage,
and the event arguments. Two executable mutations must fail:

1. Ignore the actual checked `backstore_free` return, falsely publishing
   a successful swap-in.
2. Ignore the negative `proc_swap_in` return in the scheduler service,
   falsely publishing READY_ONCE without a TERM.

Run:

```
DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross \
    sh tests/validation/daimos-swap-checked-scheduler-v1493.sh
```

Result (2026-11-11): PASS for both source-authentic checks and both
negative controls. The preceding v1405 native transaction test was
also rerun and PASSed, including repair-and-retry of the same DISK
record. The service test observes the TERM call; the actual production
`proc_event_apply` and later owner finalizer are *not* included in this
isolated fixture. Therefore the strict full 256K guest with injected
bitmap corruption, real scheduler termination, final owner cleanup
or permanently refused backing still remains OPEN. Do not treat this
native test as a full guest PASS or evidence of safe forced recovery.
