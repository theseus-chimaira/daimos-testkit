# v1577: LOGSTORE failed commit, same-slot retry and MEMFS persistence

Date: 2026-11-14. P1-C physical failure/rollback increment. This
does not assert a genuine Type-236 hardware error or concurrent swap.

## Source-matched native PDP-6 failure/rollback oracle

`daimos-logstore-fault-rollback-v1577.sh` directly links the actual
production `system/kernel/storage/logstore_runtime.s` into p10run
with the testkit's 128-word backing oracle and no replacement for
the producer implementation. The first write copies the real LSREC1
fields but clears its final commit trailer, then returns -1. The
guest verifies the original producer sequence and ring slot, zero
notification/wake count, exact failed backing location and invalid
trailer. Retry issues the same original request and commits at the
same slot and sequence, advances the cursor precisely once, and
wakes the consumer once. Native READ_BLOCK retrieves the accepted
record. Four **executed** unsafe changes to the real production
assembly are rejected: ignoring backend error, suppressing sequence
advance, suppressing slot advance, and suppressing event notification.

## Two full production KCC/PDP-6 cold boots

The `daimos-p1c-logstore-torn-v1577.py` script copies production
LOGSTORE MRES and injects exactly one event-specific error per cold
boot, leaving the normal KCORE, Type-236 driver and all unrelated
LOGSTORE messages untouched. It intercepts only the two unique
test event codes (`0157601`, `0157602`). The first corresponding
APPEND physically performs a real Type-236 LOGSTORE DMA of the exact
record *with its commit trailer cleared*, restores caller scratch,
and reports an error to the original `logstore_append` path. This
materializes an on-media uncommitted/invalid record **before** the
simulated completion error; it does not claim the controller itself
failed or that its hardware supports a sub-sector tear.

The test-enabled user program observes the negative APPEND return,
queries native LOGCTL STATUS to establish that producer sequence
and ring slot did not advance, then reads the corresponding physical
LOGSTORE sector through its real READ_BLOCK path. It requires the
unique original 36-bit sequence/payload and a zero commit trailer.
It then issues the normal APPEND retry, reads the committed physical
record and verifies exactly one cursor advance. It also creates and
checks persistent MEMFS XIP/data, and HALT snapshots the filesystem.

The second cold boot uses fresh CPU RAM and the *same* physical
AUXSTORE DSK/DRM images. The user program independently restores
MEMFS and the prior boot's unique LOGSTORE event before attempting
another first-failure/real-physical-retry sequence with a new event
code. The AUXSTORE descriptor is checked and compared bytewise
after both boots; BACKSTORE, LOGSTORE, CACHESTORE and root D6FS
remain isolated. The LOGSTORE injectable marker counters occupy
only the disposable optional MRES, never the permanent KCORE.

## Limits

This is source-matched and physically writes/reads the torn record,
but the *error completion status* is injected in a copied optional
MRES, not produced by a naturally failing Type-236 controller. The
guest retries and replaces the invalid record before reboot, so it
does not independently prove recovery of an abandoned torn record.
Nor does it prove concurrent live process swap restoration during
snapshot commit, cross DEVICE/VOLUME loss/return or PI-owner cleanup
after an actual controller failure. P1-C remains OPEN.
