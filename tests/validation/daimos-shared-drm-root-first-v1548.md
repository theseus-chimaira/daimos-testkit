# v1548: real PDP-6 root-first error with live BACKSTORE ownership

Date: 2026-11-13. Final KCORE P0-A shared-device acceptance.

## Test scope and method

The v1547 physical full-guest swap experiment is reused, with
`ROOT=drum BOOT=drm` on four real DR0..DR3 D6FS root media and
the installed BLOCKSET VOLUME mapping its BACKSTORE tail on those
same devices. This is a genuine 256K KCC PDP-6 boot using the
normal KINIT, MRES, D6FS, scheduler and filesystem access paths.

The source changes for this experiment affect ONLY a disposable
full-guest copy; production DAIMOS code is not modified:

- `daimos-shared-root-first-probe-v1548.py` changes the already
  live independent F07 spinner PID5 to issue normal `dsys_open`,
  `dsys_seek`, `dsys_read_words`, and `dsys_close` on the authentic
  selected root file `/SYSTEM/INIT`. It preserves the v1348
  high-pressure warmup and the parent/child F07 swap workload.
- `daimos-shared-root-first-arm-v1548.py` arms the accepted v1511
  **selected actual Type-236 PI2 descriptor** error observer ONLY
  after a real D6FS BCACHE miss with published D6FS mount ID 1,
  `backstore_enabled` and `backstore_blocks_used` nonzero. It
  records actual BACKSTORE ownership at that moment. Earlier
  test-only swap read/write fault selection is disabled for this
  variant; no error or successful I/O return is forged in D6FS.
- On the real physical request's PI2 completion, the unchanged
  Type-236 driver error path publishes a failed descriptor and
  wakes the waiting filesystem caller. The genuine v1538 root
  service classifier enters the v1515 root-specific `HALT .`.

This is a selected injected PI2 error branch on an actual Type-236
request, NOT a demonstration of naturally detached medium or an
independent hardware ERROR-status bit. The scope matches v1547's
already accepted BACKSTORE-first physical test.

## Physical evidence and strict acceptance

The guest completed initial KINIT and initialized its D6FS root,
BLOCKSET, LOGSTORE, MEMFS and process-swap services. Its five
pre-fault samples showed zero selected PI2 errors. Its one actual
selected root-data request then produced:

| Field | Observed octal value |
| --- | --- |
| linked v1515 critical entry | `003740` |
| real simulator HALT at ROOT leaf | **`003743`** |
| other (BACKSTORE) HALT, not reached | `003747` |
| selected physical PI2 error count | `000001` |
| root-armed actual cache-miss count | `000001` |
| BACKSTORE blocks owned when armed | **`000320`** |
| BACKSTORE blocks still owned at HALT | **`000320`** |
| BACKSTORE enabled | `000001` |
| `device_region_map` | `400000000000` |
| mapped VOLUME data blocks | `000000075774` |
| selected D6FS root vnode | `060101000000` |

`daimos-shared-drm-root-first-verify-v1548.py` requires the exact
linked root HALT (not merely some HALT), matching raw/console
evidence, actual PI2 descriptor/error path in copied source,
published root and selected DRM boot media, actual root-miss arming,
unchanged nonzero owned backing blocks, valid BLOCKSET VOLUME
mapping, and the clean pre-error samples. **Thirteen** independently
corrupted source/evidence variants are rejected; all PASS. The
v1548 host acceptance script exits 0; its wrapped original v1075
workload returns 1 because the real processor executed HALT.

SHA-256 evidence (console, raw SIMH trace, linked KCORE map, boot
configuration respectively):

```
ac74973da8f47d140dc7de7b7d86f128c27f61c667639e56c737588aa32859fb
da394ceb73493630c66812a28eb9331024f84abb6c88eb10956d23e06b1cf9c5
9da5a72db21adca868accb7f3262afc928ddbe1cb00ec72b87d3129e536f9ee1
9352fbcc7513cb459faeedcaea343f8f04ace8acd7f01d9eeb35bbf80125c959
```

Retained test evidence under
`$TMPDIR/daimos-oom-requester-live-v1075.T33gJ7`.

Reproduction:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-shared-drm-root-first-fullguest-v1548.sh
```

## KCORE P0-A status

The accepted v1538-v1547 native and real 256K full-guest matrix
already demonstrated selected TSFS and D6FS root outage, independent
noncritical DTFS/D6FS errors, direct and mapped BACKSTORE failures,
and shared-media BACKSTORE-first behavior. **v1548 now demonstrates
the missing root-first physical order while actual BACKSTORE owners
exist. The stated KCORE P0-A fail-stop policy and acceptance matrix
are COMPLETE.** This does not imply that every possible physical
hardware failure has been tested or that natural media removal is
equivalent to a controlled PI2 error. No production code, resident
memory, ABI or on-media representation is changed.

Continue with separate P0-B DTFS durable poisoning, then P1-C
combined swap/MEMFS persistent snapshot. These remain OPEN.
