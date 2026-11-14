# P1-C v1581: actual Type-236 PI2 snapshot failure with swapped owners

Date: 2026-11-14. Scoped full 128K KCC/PDP-6 physical test of
the direct DEVICE BACKSTORE route. No production DAIMOS source edits.

## Source and physical setup

The versioned `daimos-p1c-snapshot-pi2-physical-v1581.sh` copies the
entire kernel and installed stand into a unique `$TMPDIR` test source.
It reuses v1580's actual privileged MEMFS snapshot/LOGSTORE workload:
four 24K-word private-image children must each reach PROCINFO SLEEP,
and the original KCORE `proc_swap_blocks_used` must be nonzero when
the parent initiates MEMFS snapshot HALT.

The disposable `daimos-p1c-snapshot-pi2-v1581.py` instruments exactly
three original source locations. The fixed `backstore_write` gateway
marks only a one-sector write to the final BACKSTORE logical sector,
from a buffer whose first word is zero, while process swap ownership
is live. The Type-236 runtime request constructor binds exactly the
resulting real three-word stack request descriptor; the PDP-6 PUSHJ
stack convention means the caller views its address/operation/status
at AC17 offsets -2/-1/0. The original Type-236 PI2 handler waits for
the real DR_DONE and only for that exact active descriptor redirects
the completion to the existing driver `drm236_pi_error` path. It does
not force a negative return at the BACKSTORE gateway or bypass real
physical DMA. Five test-only fixed witness words are declared in the
isolated diagnostic KCORE and are read back by the simulator *after*
the real HALT. No production installed code, memory or media changes.

## Actual guest results

- Full 128K PDP-6 boot with DSK270 root and DRM236 AUXSTORE, active
  D6FS/MEMFS/LOGSTORE; root logged genuine LSREC1 APPEND/READBACK.
- Four separate 24K-word sleeping processes and parent HALT request
  observed. The fixed KCORE owned-swap counter was nonzero.
- The Type-236 PI2 DR_DONE interrupt was selected once. The original
  driver completed precisely that descriptor with an error and the
  original BACKSTORE gateway reached fatal reason 2.
- Linked `kcore_critical_device_lost_v1515=004002` and the unique
  BACKSTORE HALT PC `004011` (octal) matched the real transcript.
- Post-HALT words: injected PI2 errors `1`, the **original DRM driver**
  error counter at `mfsdev_storage_errors+5` also `1`, BACKSTORE used `01374`
  octal blocks, enabled `1`, selected relative block `07777`, actual
  physical Type-236 group address `0157670`, descriptor `0`, arm `0`.
- Independent physical drum inspection located the BACKSTORE
  `05770+010000` and separate LOGSTORE `05370+0400` regions.
  The selected final physical sector was `015767` octal, its first
  36-bit word was zero rather than the v2 commit magic, and 248
  nonzero sectors remained below the snapshot. AUXSTORE descriptors
  were unchanged. Since this is the first boot's new snapshot, zero
  media bytes alone cannot prove a write; the selected genuine DR_DONE
  and physical address establish the actual transfer completion.
- Seven independent corrupted postflight witnesses were rejected:
  no PI2 error, missing original driver error accounting, no swap
  owner, incorrect drum group, unterminated
  descriptor, wrong fatal PC and a falsely committed on-media header.

The exact source-linked postflight is
`daimos-p1c-snapshot-pi2-verify-v1581.py --self-test`. The full test
does not rely on shell command success alone: the real hardware
completion, selected address, swap account, fatal HALT PC and physical
disk data must all agree.

## Scope limit

The fault is a **selected test-induced PI2 completion error** after
a genuine physical Type-236 DONE event, not naturally failing media.
It uses a direct DEVICE BACKSTORE range, not a mapped multi-member
VOLUME. There is no separately scheduled process swap-in completion
between snapshot physical transfers. This test closes only the
physical direct-DEVICE snapshot failure propagation slice of P1-C;
overall P1-C remains OPEN for those separate cases and exact
BCACHE/MM/PI rollback across mapped providers.

Run:

```
DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross" \
    sh tests/validation/daimos-p1c-snapshot-pi2-physical-v1581.sh
```

Set `V1581_KEEP_WORK=1` to retain the versioned evidence directory.
