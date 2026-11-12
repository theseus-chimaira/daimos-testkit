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
