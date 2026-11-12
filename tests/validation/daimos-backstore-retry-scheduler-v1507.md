# Native PDP-6 BACKSTORE retry scheduler, v1507

Test command:

```sh
DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross \
  sh tests/validation/daimos-backstore-retry-scheduler-v1507.sh
```

The runner first requires existing v1493 source-authentic checked
release and its two executable negative mutations. It then extracts
the real `proc_swap_mres_service_v481`, `proc_swap_in`,
`backstore_verify_allocated_v795`, `backstore_free`,
`proc_select_runnable_pdp6` and the actual PI6 clock increment.
Backend MM and read responses are supplied by the existing v1405
native fixture (not simulated as scheduler decisions).

Slot 2 has a genuine corrupt bitmap; slot 3 has an invalid distinct
DISK owner, and slot 1 is an eligible resident bystander. These cases
must show:

- A real failed checked release sets only slot 2's retry epoch, no
  false RESIDENT/READY_ONCE, retained DISK/bitmap/MM accounting;
- slot 3 is immediately eligible despite slot 2's failed restoration,
  both in ordinary and realtime selection;
- the separate allocator-pressure global cooldown still suppresses
  all swapped candidates (unchanged behavior);
- a second fatal swap-in refusal sets an independent retry epoch for
  slot 3; neither failed owner creates a slot-0 busy loop and the
  resident bystander remains dispatchable;
- the PI6 clock, not driver-forced service calls, advances retry
  eligibility exactly after 0100 octal ticks, with expired markers
  removed;
- explicit bit repair restores slot 2 and releases exactly the
  original BACKSTORE allocation;
- a subsequent failure near octal 0377770 expires correctly across
  the 17-bit clock epoch wrap.

Negative mutants must be rejected by executable native assertions:
`no-stamp`, `no-normal-gate`, `no-rt-gate`. The old v1493 unsafe
false-ready and false-checked-release mutations must remain rejected.
v1505 separately verifies six deliberately forced failures and an
immediate successful repair, retiring the retry tag without any PI6
tick between failure and success.
The v788 native checked paired publish and v854 full sector/PURE
exchange regressions now assert B's retry tag is retired; v854 keeps
its original compressed PURE decode fixture and aliases the current
grouped-codec entry to that controlled test decoder.

Limitations: Native scheduler/transaction acceptance, not a full
physical PDP-6 persistent-media failure. The test does not establish
real device failure timing, parent WAIT behavior, administrative
recovery, or terminal reclamation of irreparably lost backing.
No full-guest acceptance is implied by the successful 256K image build.
