# v1500: real foreign TERM through PREVM finalizer and idle retries

The production `proc_event_apply`, `proc_finish_slot` and
`proc_finish_service_v881` are extracted unchanged and linked together
for native PDP-6 instruction execution. The victim has a stable
resident u-area, a nonresident DISK VM record, no WAIT class or
prior pending fatal, and a verified user-mode saved return.

The controlled FILE close succeeds. The controlled VM destroy first
refuses release without touching its disk VM owner, then accepts it
on the first slot-0 retry. The controlled u-area MM release refuses
twice before accepting the third attempt. The test verifies:

- real TERM delivery returns refusal with FINALIZE+PREVM,
  TRANSITION, original DISK owner and exact event exit status retained;
- duplicate foreign TERM is rejected while the finalizer owns retry;
- slot-0 first retries VM and then u-area MM without repeating HUP,
  FILE closure or a committed VM destruction;
- the terminal process is published as a zombie only after release;
- later slot-0 finalizer scans cannot free or notify twice.

A negative mutation removes the actual production PREVM pending
publication from `proc_finish_prevm_fail_v1081`. The fixture rejects
the missing retained owner, proving the checked failure path matters.

Run with `DAIMOS_REPO` and `PDP10_PREFIX` set:

```
sh tests/validation/daimos-backstore-event-finalizer-v1500.sh
```

Status: native positive and negative gates PASS. No production kernel
or resident RAM changes. This unifies the **event + finalizer** source
that earlier v1493/v1494 tested as separate leaves. The underlying
`vm_space_destroy` and physical BACKSTORE bitmap are still controlled
in v1500; the full 256K corrupt-bitmap physical gate is not thereby
accepted. Physical v1499 branch evidence is a separate requirement.
