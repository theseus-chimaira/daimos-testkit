# KCORE: Type-236 lost PI2 completion and production PI6 timeout, v1512

Date: 2026-11-12. Physical acceptance **OPEN** pending the full
booted PDP-6 guest; preparation and native negative checks are not
device-loss acceptance. This test belongs exclusively to daimos-testkit.

## Intended physical failure and why it is different from v1511

v1511 redirects the completion of the selected real Type-236 drum
request through the existing PI2 error branch, causing an immediate
failed request. It does not test loss of the completion notification.
The production Type-167/236 driver already contains a 300-tick
PI6 watchdog (`drm236_watchdog_tick_v1079`) that must fail and wake
a real outstanding stack descriptor if its controller never publishes
completion. Existing native v1079 exercises precise countdown,
pending FIFO promotion and no duplicate wakeup; v1080 also validates
full-queue admission. v1512 exercises that same watchdog on real
F07 BACKSTORE swap-in I/O in a booted disposable 256K PDP-6 guest.

After v1510/v1511 source-linked instruments have been inserted in
a **disposable copy only**, v1512 selects the first two genuine
post-fault reads of the original bad owner. The Type-236 hardware
performs the real transfer and asserts `DR_DONE` on PI2. Instead of
publishing that completion, the test-only branch deselects the drum
and preserves the actual active private descriptor. Only the
unchanged real PI6 300-tick watchdog may subsequently complete that
descriptor with -1, account the storage error, wake the original
slot-0 process, and allow its original MM unpin/rollback. The test
instrument counts two lost PI2 completions and separately counts
the real timeout branch when its descriptor pointer matches.

The initial v1508 selected BACKSTORE extent remains allocated,
and subsequent swap-ins revert to the original checked-free refusal.
The independently delayed healthy swapped PID `011` and resident
PID 5 spinner must make actual progress; their own Type-236 I/O
requests remain unmodified. No production KCORE source, process
state, interface, memory or hardware driver is modified by the
test. The physical bitmap remains authoritative.

## Verifier and strict boundary

The physical v1512 verifier requires both lost-completion and
authentic PI6-timeout witnesses to reach exactly two. It rejects
any selected PI2-error publication; v1511's distinct `device_errors`
counter must remain zero. The DRM controller's *real* error
accounting must cover both watchdog failures. Its inherited v1511
ownership verifier checks each source-linked failed-service return
against real timeout plus checked-free refusal, preserves DISK
record/u-area/TERM/MM accounting and rejects false READY_ONCE,
finalization, and missing resident or swapped user progress.
The test normalizes the separately named timeout count solely
inside the verifier to reuse these exact source-independent checks.

Native prerequisite selftests:

- v1512 source inject: original watchdog/descriptor retirement
  retained; four malformed source variants rejected.
- v1512 physical verifier: twelve unsafe error/rollback/owner/user
  evidence mutations rejected.
- v1079 production source-linked clock/watchdog and v1080
  full queue admission PASS; v1247 PI AC3..AC6 preservation and
  its four negative tests PASS.

Run:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
sh tests/validation/daimos-backstore-watchdog-physical-v1512.sh
```

`V1512_PREPARE_ONLY=1` performs source fixture selftests, prepares
the full test guest and compiles the sampler without executing it.
Full acceptance requires real fault-on snapshots and the exact
physical verifier, not a mere successful compile or native mock.
The guest is deliberately sample-stopped, not a normal all-child
HALT; its failed original DISK owner cannot be falsely released.

The scenario simulates a lost completion notification after a real
DMA transfer, **not** permanent disappearance of the Type-236
hardware or unrecoverable physical magnetic-media damage. Device
reconstruction and owner policy remain separate OPEN issues.

## Current state

Self-tests and generated runner/sampler preparation PASS. Booted
physical timeout capture and acceptance remain OPEN. No release
status or KCORE size acceptance is claimed.

Before physical acceptance, v1512's strict verifier was corrected
to decode the digit-bearing `lost_pi2` sampler field explicitly.
The inherited v1508 evidence parser only recognizes alphabetic
field names, which would otherwise silently omit this counter.
The new local parser preserves the original octal decoding and
rejects a missing `lost_pi2` field; both positive and missing-field
native parser controls PASS. No v1508 parser or production code
was modified.

## Physically accepted Type-236 lost-completion / PI6 timeout boundary

The corrected v1512 256K KCC PDP-6 full F07 stress guest produced
39 read-only SIMH samples, including **16 actual fault-on snapshots**
(24..39). The injector selected one genuine BACKSTORE owner after a
successful real drum transfer. The next two selected real Type-236
`DR_DONE` interrupts acknowledged hardware but did not publish their
completion. The actual live stack descriptor stayed outstanding for
the original 300-tick PI6 watchdog to complete with -1 and wake
its owner. **No direct Type-236 PI2 error was injected** in v1512.

The original bad process is octal slot `010`, BACKSTORE first
`02350`, count `0330`, exact authoritative DISK run
`002350000330` at every fault-on snapshot. The original bitmap
and used-block accounting, stable u-area, pending TERM, and v1507
retry marker persisted. There was no false RESIDENT/READY_ONCE,
repair, owner-side fatal close, finish, zombie, or backing free.

| Sample | PI6 clock (decimal) | Lost PI2 | Real PI6 timeouts | Refused checked frees | PID 5 SLEEP | PID 011 SLEEP |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 24 | 36219 | 1 | 0 | 1 | 42 | 0 |
| 25 | 37740 | 2 | 2 | 2 | 141 | 0 |
| 26 | 39259 | 2 | 2 | 4 | 207 | 0 |
| 27 | 40778 | 2 | 2 | 6 | 273 | 0 |
| 28 | 42298 | 2 | 2 | 8 | 339 | 0 |
| 29 | 43818 | 2 | 2 | 10 | 405 | 0 |
| 30 | 45337 | 2 | 2 | 12 | 471 | 0 |
| 31 | 46855 | 2 | 2 | 14 | 488 | 16 |
| 32 | 48381 | 2 | 2 | 16 | 572 | 100 |
| 33 | 49897 | 2 | 2 | 18 | 638 | 166 |
| 34 | 51417 | 2 | 2 | 20 | 704 | 232 |
| 35 | 52938 | 2 | 2 | 22 | 770 | 298 |
| 36 | 54460 | 2 | 2 | 24 | 836 | 364 |
| 37 | 55980 | 2 | 2 | 26 | 902 | 430 |
| 38 | 57501 | 2 | 2 | 28 | 968 | 496 |
| 39 | 59022 | 2 | 2 | 30 | 1034 | 562 |

At sample 24 the observer showed `lost_pi2=1`, `watchdog_errors=0`
and an active live DRM request pointer with a nonzero watchdog
countdown: an actual outstanding request, **not a fabricated early
failure**. By sample 25, `lost_pi2=2`, `watchdog_errors=2`, and the
real DRM storage-error counter reached 2. The direct PI2 error
counter remained zero. The final exact source-linked failure
accounting was **32 = 2 real watchdog timeouts + 30 checked-free
refusals**. No failure source was relabeled to match the checker.

Over 22,803 real PI6 clock ticks the independent resident PID 5
spinner executed **992** further genuine user SLEEP calls
(42..1034). An independent real child, slot `011`, was SLEEP/DISK
at sample 30, was restored via one genuine checked ordinary
swap-in by sample 31, and executed **562** genuine SLEEP syscalls
through sample 39. The fallback checked exchange count remained 0.

The strict v1512 physical verifier PASSED on the finalized full
sampler and guest console. Its native evidence-mutation selftest
rejected twelve unsafe ownership/timeout/restore cases plus a
missing digit-bearing `lost_pi2` source field. The source-injector
selftest rejected four malformed Type-236/PI6/descriptor sites.
Existing production source-linked v1079 timeout, v1080 queue and
v1247 PI register-preservation tests also PASS.

### Exact physical evidence fingerprints (SHA256)

Guest: `$TMPDIR/daimos-oom-requester-live-v1075.VY224I`.
Runner: `$TMPDIR/daimos-swap-no-partner-v1304.ThXyOe`.

```
addresses          5a4f58057cf89e3b6eb14e5d13f314dcfb20c2061d416de3bc1221637416c540
simh-sampler.log   6f88c9084d9258ed907f81d375b8c60aef940f0e3061a2e2b603bae1b1d4812c
simh.out           4fdcf2867c18ef99a8a58827a590e879b25c59672cf2def2d26b15c2b07074c4
build.log          24902fc2b1926f4c951f996f46cb4562457d07134c27ffba614d8f04d769840a
kcore.map          0de350b2b9afbcb2414bea441151f9c11fbc389d613a2849074b478fd23ad218
```

The diagnostic intentionally stopped after sample 39. Normal F07
postflight rc=1 is expected while the original unrepaired DISK owner
still holds backing and cannot consume private pending TERM; **no
normal HALT/EXIT or terminal reclaim is claimed**. The test proves
lost Type-236 PI2 completion, genuine original PI6 timeout,
negative BACKSTORE read/MM rollback, healthy process progress and
fail-closed ownership under this injected failure. It is not
physical magnetic-media loss, complete controller disappearance,
permanent media reconstruction or forced cleanup.

**Scoped v1512 physical acceptance: PASS.** Production KCORE
remains unchanged; no new permanent process state, resident RAM,
or ABI. The remaining unrecoverable-DEVICE recovery policy and
mixed provider/PURE/FSINFO feature gates are separate.
