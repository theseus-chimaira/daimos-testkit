# v1535: race-free guest CTY acknowledgments for physical media gates

Date: 2026-11-13. Testkit-only change, no production kernel or
filesystem code modification.

## Reproduction

The v1527 physical hot-swap test had an intermittent stall after
`DTFSMEDIA V1527 READY_SWAP`. On failure it produced no following
`DTC4_PREPROBE_OK` or explicit FSINFO rejection code. A break
showed KCORE's idle loop, not a completed physical storage error.

The test runner previously sent both `cont\n` and `A\r`
consecutively on the SIMH monitor's stdin. SIMH monitor command
processing is separate from its PDP-6 CTY keyboard poll; this
input is not a deterministic handoff to the resumed guest.
The v1535 diagnostic guest prints `SWAP_ACK_RECEIVED_V1535`
only after the real PID1 CTY READCHAR has returned.

The first experiment using SIMH's `SEND AFTER=10000` queue passed,
but a repeat stalled even earlier at `READY_DETACH`.
Interrupting that experiment at the idle loop and issuing
`SHOW SEND` reported `No Pending Input Data`. The queued
characters had left SIMH's SEND queue, but PID1 had not observed
the required input. This remains a test synchronization failure.

## Correct implementation

Read the actual CTY source `sims/PDP10/kx10_cty.c`:
output takes `10000` simulated instructions per character.
An observed `READY_*` substring does not necessarily include
the final CR/LF or mean the guest has entered READCHAR.
Therefore an injection delayed by only 10000 instructions
can be too early.

The runner now writes the following **one monitor command**
after each real detached/replaced/returned media operation:

```text
SEND AFTER=200000,DELAY=20000,"A\r"
```

It waits for a successful SIMH monitor prompt (checking error
output), then writes `cont\n` **alone**. SIMH's existing SEND
engine injects A and CR into the *simulated CTY*, respectively
after 20 output-character periods and with two further character
periods of spacing. This provides a bounded, guest-instruction
based transition after finishing the stage output and entering
the blocking read. No host-side timing sleeps, duplicate/retried
characters, artificial host filesystem callbacks, production
guest hooks or relaxed original media checks are introduced.

The separate diagnostic entry
`daimos-dtfs-hot-swap-ack-v1535.sh` preserves the original v1527
strict physical hot-swap checks, with the single additional
post-READCHAR witness.

## Physical acceptance

With the corrected queued input, the v1527 physical guest
again refuses detached and incorrectly stamped replacement
DTC3, keeps healthy DTC4 accessible, checks the original
72-bit ID on physical return, reuses the previously held
FILE and closes/unmounts both mounts. It reports
`RETURN_VERIFIED` and `PASS`, and the host exits zero.
The same test completed on an independent repeat.

Five independent physical gates PASS with the revised
transport on the same full 256K KCC PDP-6 build:

* v1527 strict replacement, authenticated return and held
  FILE: PASS twice with the delayed console-send transport.
* v1528 physical failed WRITE, matching-ID return still
  WRITE_UNCERTAIN and retained mount/descriptor: PASS.
* v1531 privileged and owner-checked destructive replacement,
  rejecting the same damaged tape: PASS.
* v1534 simultaneous TSFS root, poisoned DTC3, healthy DTC4
  and MEMFS with real file-content checks: PASS.
* v1529 diagnostic Type-551 physical incomplete WRITE on
  RBN0145: one changed and one unchanged requested word,
  sticky WRITE_UNCERTAIN on return. Host physical-media
  oracle and guest PID1 PASS.

These independently verify the real intended storage behavior
without relying on a fabricated controller status or weakening
the original guest assertions.

KCORE version 0.5, strict 32K/optimization HOLD. No change to
fixed KCORE, optional MRES, native disk/tape structures, media
identities or permanent RAM.
