# KCORE BACKSTORE: bounded physical permanent-refusal diagnostic, v1508

Date: 2026-11-12. Only the disposable 256K PDP-6 guest is patched.
The linked production KCORE v1507 code is otherwise unchanged.

## Test scope

This builds on the previously accepted v1504 F07 source-linked
physical owner-return instrumentation. Once an actual successful
BACKSTORE swap-in payload read selects an ordinary slot, v1508 keeps
the **real bitmap** intact but forces every checked BACKSTORE release
of that exact physical run to return refusal. The selection is
not predetermined by the fixture. No unrelated BACKSTORE run is
intercepted. Unlike v1494/v1504, no bitmap bit is deleted, and no
third-attempt repair is performed.

The production `proc_swap_in`, real MM pin/unpin, rollback, slot-0
service, foreign TERM delivery, scheduler and clock stay active.
Instrumentation separately snapshots the real selected slot,
original run, current swap record, process descriptor fields,
retry epoch, FD control, and private finalizer counters after each
failed service. Physical SIMH Ctrl-E sampling is read-only; only the
disposable guest holds the extra diagnostic words.

Use:

```sh
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
sh tests/validation/daimos-backstore-persistent-physical-v1508.sh
```

Optional `V1508_PREPARE_ONLY=1` checks the versioned runner and
generated sampler without building or executing the full guest.
`daimos-backstore-persistent-verify-v1508.py --self-test`
checks that ten unsafe witness mutations are rejected.

## Strict physical criteria

After the selected physical fault, require at least three bounded
sampling intervals and more than one refused release; a stable
selected slot and **exact** original DISK first-block/count; no
RESIDENT VM, lost u-area, pending TERM consumption, successful
owner return/finalizer, zombie or repair. The latest real
owner-specific retry tag must remain set with FINALIZE clear.
Refusal increments between actual PI6 timer snapshots must not
outpace the fixed 0100-octal-tick retry cadence.

This diagnostic intentionally asks the SIMH sampler to stop after
the requested samples, while the failed owner still exists. A
normal F07 HALT/EXIT acceptance is neither expected nor accepted.
The wrapper reports the ordinary strict postflight rejection
separately; v1508's verifier must pass independently on the
preserved physical sampler and console logs.

The test is **not** a claim of an actual broken DEVICE controller,
irreparable data reconstruction, administrative repair, or terminal
reclamation. It models a permanently refusing checked release
against a real physical swap owner. The long-lived resource-owner
policy remains a separate OPEN issue even if bounded scheduling
passes.
