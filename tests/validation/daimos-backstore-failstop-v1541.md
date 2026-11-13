# v1541: critical BACKSTORE service I/O fail-stop

Date: 2026-11-13. KCORE P0-A feature policy; no optimization.

## Exact production boundary

`system/kernel/fs/fs_mres.s` implements the only fixed gateway for
`backstore_read` and `backstore_write`, including direct DSK270 and
DRM236 DEVICE and mapped multi-member VOLUME. It validates the whole
request before initiating any transfer. At the common post-transfer
return, a negative result from the driver or the installed VOLUME
mapper enters `kcore_critical_device_lost_v1515` with reason 2 when
`backstore_enabled` is nonzero **or** `backstore_blocks_used` is
nonzero. The actual v1515 terminal leaf disables PI and HALTs at the
unique BACKSTORE instruction PC. The gate never releases, reallocates
or invents successfully restored process owners.

The additional ownership check is essential: `STORAGECTL` can stop
*new* swapping without retiring already swapped process blocks. It
does not make that existing BACKSTORE optional. When the service is
disabled and has no allocated owners, a boot-time optional MEMFS
snapshot probe returns its original failure instead of HALTing. A
zero-length transfer returns success; invalid buffers and out-of-
bounds requests fail without a hardware transfer or HALT.

This deliberately supersedes the older v1511/v1512 acceptance of a
final negative, otherwise valid BACKSTORE read returning to the
process scheduler to retry later. Ordinary controller retries still
occur before the driver publishes failure. A surviving controller
that would have responded to a *new* later request is no longer
sufficient to keep a critical process backing service running.
This is the same strict fail-stop trade-off already accepted for the
selected root filesystem in v1538.

## Native tests

Run `daimos-backstore-failstop-v1541.sh` with DAIMOS_REPO and
PDP10_PREFIX. It extracts the exact current assembly backing
gateway and the actual v1515 root/swap/invalid-reason HALT leaf;
only controller return status is simulated. The PDP-6 executes:

- Negative direct DSK270 and DRM236 READ and WRITE results;
  failure on the second of two physical blocks;
  missing VOLUME mapping; disabled-but-owned service failure.
  All must HALT at the **BACKSTORE**, never the root, HALT PC.
- Negative disabled/unowned read and VOLUME mapping; successful
  reads, writes and two-block transfers; valid zero-length transfer;
  invalid first block, oversized run, NULL buffer and missing
  configured region. None may HALT.
- Six mutated actual-source alternatives must be rejected by
  executing the native test oracle: missing HALT dispatch, root
  reason instead of BACKSTORE reason, bypass enabled/owned state,
  HALT after successful transfer, and bypass mapped failures.

The tape-profile fixed KCORE and TSFS MRES KCC links PASS. Physical
acceptance is separately exercised by
`daimos-backstore-failstop-fullguest-v1541.sh`, which reuses the
v1511 real Type-236 PI2 selected-descriptor error injector in a
disposable 256K KCC guest but expects a BACKSTORE HALT rather than
the old recovery policy. No production source is modified by this
injection and no simulator-only condition exists in KCORE.

Do not count any unexecuted physical test as passed. A real positive
physical BACKSTORE HALT witness is required for complete acceptance.
