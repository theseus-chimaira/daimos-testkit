# P1-C v1600: two PI6 owners at direct DRM0 DEVICE BACKSTORE fatal

Date: 2026-11-15. Full real 128K KCC PDP-6 cold boot with **selected
four-member DSK270 D6FSR2 root** on DSK0..DSK3 and a completely
separate **Type-236 DR0 AUXSTORE** physical medium containing direct
DEVICE BACKSTORE, LOGSTORE and CACHESTORE. This is an intentionally
different topology than v1599's shared-root interleaved DRM VOLUME.
The original KCORE, MINIT, scheduler, swap service, MM, D6FS,
MEMFS, BACKSTORE gateway, driver and fatal policy remain unchanged;
only a disposable test-only copy holds source-linked observers and
the selected real-PI2 error redirect.

The accepted v1584/v1585/v1592 testkit observers select two
different timed original SLEEP/DISK children, slots **6 and 7**,
with real positive swap backing records. At the MEMFS shutdown
snapshot the observers retime these existing sleeping owners to
the next 60 Hz PI6 tick; the **original** timer service wakes both
once, and the original slot-0 service begins a real swap READ for
slot **6**. The selected first *authentic* Type-236 DR_DONE PI2
is test-directed to the existing `drm236_pi_error` path, and the
unaltered BACKSTORE critical classifier executes its required
reason-2 HALT at octal **`004011`**. This is a selected fault on
a real simulated hardware completion, not natural media damage.

## Original linked memory and physical observations

| Accepted independent observation | Original value |
| --- | --- |
| 128K PDP-6 root controller | DSK270, not DRM |
| Exact four physically independent root member IDs | `074040000`, `074240000`, `074440000`, `074640000` octal |
| Physically separate AUXSTORE medium | DR0, 8192 128-word sectors |
| Physical RBN0 descriptor | SIXBIT AUXST1, format version 1 |
| Physical BACKSTORE range | `05770+010000` octal sectors |
| Separate LOGSTORE range | `05370+0400` octal sectors |
| Original `device_region_map` | `400000005770` octal |
| Original `volume_data_blocks` | **0**, no VOLUME mapping |
| Original `backing_region_count` | `010000` octal |
| Actual timer-scheduled disk-backed owners | 6, 7 |
| Original PI6 wake counts | 1, 1 |
| Selected original swap READ owner | 6 |
| Original swap READ/DR_DONE PI2/error counts | 1/1/1 |
| Actual physical DRM0 READ sector | `006421` octal |
| Logical direct-DEVICE BACKSTORE relative sector | `000431` octal |
| Original process-owned BACKSTORE blocks | `01650` octal |
| Original total allocated BACKSTORE blocks | `01734` octal |
| Original successful RESIDENT publishes | **0** |
| Original required BACKSTORE fatal HALT | `004011` octal |
| Snapshot commit header at last direct BACKSTORE sector | **0**, uncommitted |
| Other independently nonzero physical backing sectors | 268 |

The independent raw-media oracle authenticates all four actual
DSK270 root header sectors, their different member identities,
matching geometry and correctly-sized member images. It separately
parses the *physical* DR0 AUXSTORE RBN0 words and compares their
BACKSTORE and LOGSTORE geometry to the pre-boot `mkauxstore --inspect`
text. It derives the actual hardware DMA sector and verifies that
the selected physical sector contains original nonzero swapped
payload. `volume_data_blocks` is zero and original `device_region_map`
is precisely the DRM direct selector plus AUXSTORE physical start;
no interleaved VOLUME mapper participates. It checks the genuine
DRM error accounting, original outstanding swap ownership, unchanged
process-state publication count, uncommitted MEMFS snapshot, and
the *exact original linked* reason-2 critical HALT.

The full physical guest and independent strict oracle **PASS**.
**27** deliberately corrupted evidence controls rejected:
eight original two-owner PI6/wake/identity variants, fifteen
original PI2/HALT/owner/physical-data/snapshot variants and four
independent DSK270-root/AUXSTORE/false-VOLUME variants. The v1599
mapped VOLUME 23-mutation and v1586 single-owner 15-mutation
regressions both continue to PASS with the generalized oracle.

## Limits and correction of v1599 wording

The genuine scheduled READ happens for only one of two owners
before the required fatal HALT. No other process may finish I/O
after the critical failure, so this is **not** a continuing-service
or dual concurrent DMA acceptance. The independent DSK270 root
was successfully used to boot and access the installed workload
*before* the fatal BACKSTORE request; its four physical layout
headers are valid after the HALT. This does not prove every
pending root metadata write finished normally during an abrupt
critical stop. LOGSTORE append/readback succeeded before the
snapshot failure, not after it. Natural physical device loss,
dirty/write-through errors and repeated timing under load remain
separate tests.

Postflight reading of original v1599 KCORE-linked `last_slot`
confirms that v1599's first fatal swap READ ALSO belonged to
slot **6**, whereas the original v1599 prose mistakenly claimed
slot 7. Both v1599 owners (6 and 7) really were PI6-woken; its
accepted original verifier required one member of that correct
pair and thus remains valid. The v1599 historical report and
DAIMOS/pdp10-doc narrative have been corrected accordingly.

Reproduce from daimos-testkit:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
V1600_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-device-two-owner-fatal-physical-v1600.sh
```

Retained real evidence:
`$TMPDIR/daimos-p1c-device-two-owner-v1600.kaKCCA`, including
`v1600-physical-verification.txt`, `v1600-verifier-output.txt`,
two physical medium classes, original KCORE map and post-HALT
original memory, source code, and full guest build/run logs.

P1-C still open for dirty/write-through/provider isolation and
loaded repeatability. P1-D final source-matched matrix and P1-E
KA10-aware architectural review remain pending. Production
DAIMOS VERSION 0.5, KCORE low end `024364` octal, 32K/optimization
HOLD and zero permanent code/RAM/ABI/media-format modifications.
