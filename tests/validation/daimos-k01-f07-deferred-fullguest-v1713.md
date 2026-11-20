# K01 v1713 fault-specific physical F07 acceptance

The original v1336/v1349 **clean** full-system F07 verifier requires
`swapin_fail == 0`. That is essential when no fault is injected.
The v1494 bitmap fault intentionally makes the exact owned DISK run
fail twice before restoring its single missing bit. Requiring the
unchanged zero-failure verifier in the same deliberately faulted run
was contradictory. Neither validator may be weakened globally.

## Faulted transaction protocol

The v1713 *disposable-kernel-only* injector reuses the original v1494
allocation, read, bitmap fault, and exact-run identity. Its source-
linked event/rollback witnesses now require:

* After either failed `backstore_free`, the provisional RAM allocation
  was rolled back and TRANSITION cleared. The original DISK record is
  still authoritative, and the sleeping process retains its private
  executive continuation. TERM is queued, not delivered with a
  premature PREVM marker.
* A subsequent restore reacquires TRANSITION. At the third exact-run
  `backstore_free`, the same TERM is still pending and PREVM has not
  been published. Repair restores **only the captured bitmap word**.
  No other run is modified.
* Two exact failed restores cause two service TERM events, rather than
  the original v1494 assumption of one synchronous TERM. Every event
  must target the original slot, and *all* injector errors must be zero.
* After the corrected run is restored, the deferred fatal event may
  complete on its original process stack. The normal final MM owner
  and backing cleanup remains mandatory.

`daimos-k01-f07-deferred-native-v1713.sh` executes the actual injected
TERM witness on a PDP-6 with exact mock owner/FDCTL/finalizer state;
three mutants fail. `daimos-k01-f07-retry-native-v1713.sh` executes
the source-linked third-free prelude against a test-only bitmap
backend, confirming two refusals and one repair; three more mutants
fail. `daimos-k01-f07-faulted-verify-v1713.py --self-test` rejects
16 unsafe counter mutations and demonstrates that the untouched
clean v1336 verification still rejects intentional fatal failure.

## Full-system acceptance

Run the versioned profile explicitly:

```sh
sh tests/validation/daimos-k01-f07-deferred-fullguest-v1713.sh
```

`V1713_PREPARE_ONLY=1` checks the injection hooks and runner structure
but does NOT provide physical acceptance. The full profile boots a
disposable 256K PDP-6 image with the original 18-child test and
v1203/v1207/v1349 acceptance checks. It only substitutes the mutually
contradictory clean v1336 swap-failure check with the strict faulted
verifier, which still independently checks the original MM owner
snapshot, the process owner release, exact typed pressure, swap
success/refusal accounting, and final BACKSTORE zero.

This profile does **not** assert that the separate ordinary clean
v1336/v1349 physical baseline passed; that must be executed and
reported independently. A successful native fixture, prepared guest,
HALT alone or repaired bitmap without all checks never counts as PASS.
