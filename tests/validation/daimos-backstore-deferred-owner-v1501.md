# v1501: deferred TERM after a nonresident owner is restored

The production `proc_event_apply` and
`proc_deferred_term_check_v926` from the PDP-6 kernel are source-
linked unchanged into a single native instruction test. The target
initially owns a DISK VM, a stable u-area, a WAIT_CHILD continuation
and an executive-mode saved PC.

Real foreign TERM delivery must record the pending TERM in the
u-area, without closing FILEs or freeing VM. A repeated TERM must
coalesce. The fixture then models successful swap restoration and
completion of the owned executive continuation: its VM becomes
resident, WAIT clears, and the saved PC is user mode. On the owning
syscall return the real `proc_deferred_term_check_v926` must:

- consume the pending TERM exactly once;
- set the private fatal-close owner bit;
- enter the private fatal-close service with status `0400001`;
- refuse later foreign teardown while the private close owns state;
- avoid repeating the private fatal service on another return.

The final private `proc_fatal_close_current_v879` is a test witness,
not the actual finalizer. The actual swap restoration is also
controlled. This test therefore verifies the event-to-owning-return
boundary and complements native v1500 (immediate foreign
event-to-finalizer), without claiming physical BACKSTORE acceptance.

A negative mutation disables the production pending-event bit clear.
It causes the TERM to be delivered twice and is rejected.

Run with `DAIMOS_REPO` and `PDP10_PREFIX` set:

```
sh tests/validation/daimos-backstore-deferred-owner-v1501.sh
```

Status: real-source native positive/negative checks PASS. No KCORE
production code, ABI or resident RAM change. The physical v1499
branch/owner evidence and fault-specific permanent backing recovery
remain OPEN.
