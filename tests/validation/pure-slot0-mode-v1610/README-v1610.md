# P1-E slot-0 DISK/PACKED mode separation (PDP-6 v1610)

Run from daimos-testkit root:

    DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/pure-slot0-mode-v1610/run-v1610.sh

The script extracts the unchanged MRES service entry and
the actual assembly two-bit mode operations from current
DAIMOS sources. Only disk I/O, exchange and fatal-event
effects are test-controlled; they are counters, not
substituted storage-mode or scheduler logic.

The native PDP-6 guest checks:

* PACKED mode (2), nonresident RUN, with a nonzero
  executable backing record: no disk-in call, no TERM,
  no READY_ONCE, unchanged record and mode, cooldown 0100.
* DISK mode (1): original swap-in, READY_ONCE and no TERM.
* Reserved invalid mode (3): refused with no disk read
  or fatal-event side effect.
* A private source mutant bypassing the disk-mode gate
  must fail a runtime assertion in the same PDP-6 guest.

The v1604 common lifecycle and the v1384/v1395 source-linked
tests separately check that RUN restoration is admissible
only when slot 0 executes a TRANSITION-owned target; DROP
may not evict a RUN process.

This test does not prove a complete production swapless
wakeup or physical boot: the PACKED service deliberately
defers until the real immutable-source and restore
transaction are installed. See DAIMOS
`design/kcore-p1e-slot0-mode-v1610.md`.
