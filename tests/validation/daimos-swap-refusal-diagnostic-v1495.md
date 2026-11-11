# v1495: diagnostic-only refinement of the v1494 physical refusal guest

This is a deliberately non-acceptance diagnostic. The existing v1494
physical 256K PDP-6 F07 run executed one injected bitmap corruption,
three exact matching `backstore_free` attempts, and one recovery of
the corrupted bit. Its final BACKSTORE and process-swap usage were
both zero. However its post-event TERM witness was zero rather than
one and its composite diagnostic error counter was one; the original
F07 accepted-child count also differed (19 versus 18). Thus the
original full-guest release gate **did not PASS**. A genuine guest HALT
alone is not sufficient evidence.

v1495 retains the same disposable one-bit fault injection and original
strict F07 postflight checks. After the base v1494 injection, it adds
read-only witness counters and raw stack/owner snapshots:

- slot-0 `proc_swap_service_failed` entry and exact request slot;
- return from the real `proc_event_apply` call;
- entry to the v1494 TERM witness and three adjacent stack words;
- independent TERM-time TRANSITION and PREVM errors;
- independent retry-time TRANSITION and PREVM errors, with raw
  descriptor and finalizer word snapshots.

These counters are allocated only in the copied diagnostic guest,
never in checked-out production KCORE. No scheduler branch, failure
policy, storage transaction, HUP or finalizer behavior is changed.

Run:

```
DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross \
    sh tests/validation/daimos-swap-refusal-diagnostic-v1495.sh
```

`V1495_PREPARE_ONLY=1` validates the complete derived runner without
starting the guest. `daimos-swap-refusal-report-v1495.py` refuses to
parse incomplete HALT/EXIT or duplicate/missing map-backed observations
and prints the diagnostic fields; it never reports physical acceptance.

The original F07 postflight must still pass in its existing form, or
the overall guest must be reported as failed. If a deliberate fault
necessarily changes a child handshake, the actual lifecycle cause and
the appropriate *separate* scoped acceptance test must be demonstrated
before redefining that expected count. Do not silently weaken F07.
