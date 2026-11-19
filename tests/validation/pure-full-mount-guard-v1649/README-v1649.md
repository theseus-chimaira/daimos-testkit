# P1-E v1649: FULL-loader pinned source and original VFS owner guards

Date: 2026-11-17. Source-linked native PDP-6 regression PASS.
No production KCORE, MM, loader, VFS, DTFS, scheduler or ABI changes.

## Validated implementation

The original `proc_pure_ram_restore_v1391.c` is compiled with
PDP-6 KCC, together with the real v1381/v1384 transactions and
MM PURE assembly. The earlier v1395/v1397 and v1648 rollback
cases run first. A separate assembler leaf is extracted byte-for-byte
from `proc_pure_backing_pdp6.s`, supplying only the historical
external constant definitions required for standalone assembly.
No production owner predicate is replaced by a C imitation.

The new FULL callback executes with the original RAW
`MM_TYPE_PACKED_PROCESS` suffix at `SOURCE+OMIT` and a separate
complete `MM_TYPE_PROCESS` APR at `RESTORE`, both *pinned exactly
once* by the real v1391 code. The process has no runnable APR base,
keeps `PROC_TRANSITION` and the PACKED storage mode, and retains
the exact PURE backing. The mount-root fixture identifies a
secondary-style DTFS provider (5), public mount 1 and file index
`012345`.

At that exact callback:

* The original `proc_swap_mount_busy(1)` returns 1 (unmount
  preflight must refuse this existing PURE executable dependency).
* The original `proc_swap_backing_busy(exact-vnode)` returns 1
  (WRITE/UNLINK/RENAME-to-other-content guard).
* A different mount and a different file index return 0, proving
  the guard is source-specific rather than an indiscriminate deny.
* Both actual MM descriptors, pins and process backing are unchanged
  by the guard queries.
* The original loader finishes, overlays the authoritative RAW
  suffix and publishes a single unpinned RESIDENT PROCESS owner
  with exact original text and writable data.

Two independently assembled invalid variants of the original
scanner (skipping the PURE text-owner match, or inverting the
backing-file identity match) are each executed and rejected by
the same native return/status oracle. They must produce a nonzero
`__test_exit`, not a syntax or linking failure.

## Run

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
DAIMOS_REPO=/path/to/DAIMOS \
    sh tests/validation/pure-full-mount-guard-v1649/run-v1649.sh
```

## Scope

This proves the original, source-linked MM and VFS owner scanners
agree during an actual FULL loader callback. It does *not* prove
an independent user process executed a DTFS unmount during a real
provider sleep. The strict v1562 unmount preflight checks the
original `proc_swap_mount_busy` without yielding before entering
the V2 quiescence barrier. Because FULL keeps the PACKED source
until after the loader returns, an ordinary competing unmount
should be refused before reaching that barrier. A separate
multi-process physical scheduler/interleaving audit remains open.

Existing separate physical proofs: v1638 pinned relocated FULL
source/target, v1643 genuine secondary provider loss and restore,
v1645 multiple owners under PI6 progress, and v1647 V2
quiescence refusing new RUN. No new RAM-saving or KA10 claim.
PURE stays disabled by default; strict 32K optimization HOLD.
