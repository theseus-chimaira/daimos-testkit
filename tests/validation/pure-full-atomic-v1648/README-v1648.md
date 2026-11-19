# P1-E v1648: FULL MM source-release/pin rollback (native PDP-6)

Date: 2026-11-17. Native source-linked regression PASS.
This test extends the accepted v1395/v1397 FULL and DROP fault matrix.
No production MM, VFS, VM, PURE, scheduler or process source changes.

## Reproduce

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
DAIMOS_REPO=/path/to/DAIMOS \
    sh tests/validation/pure-full-atomic-v1648/run-v1648.sh
```

The runner compiles the original `proc_pure_ram_v1381.c`,
`proc_pure_restore_v1384.c`, and
`proc_pure_ram_restore_v1391.c` with native PDP-6 KCC. It links
the actual `mm_pure_rebase_v1381.s`, `mm_pure_expand_v1384.s`,
`proc_storage_runtime_v30.s`, `device_state.s`, and the existing
native v1384/v1395 test fixtures into the `p10run` PDP-6 image.
Only function-name substitution at the FULL compile boundary
introduces the fault wrappers. The original v1395 test suite runs
first, without changing its old fault patterns.

## New v1648 cases

The tests enter FULL with exactly one PACKED_PROCESS descriptor,
an unpinned mutable suffix at `SOURCE+OMIT`, the original packed
backing identity, and no runnable APR. The loader succeeds and
produces a complete temporary PROCESS destination.

* Kind 7: real source release is replaced with one `MM_ERR_BUSY`.
* Kind 8: the same source release instead returns `MM_ERR_INVAL`.
* Kind 9: the newly allocated FULL PROCESS destination refuses
  its first `mm_pin` with `MM_ERR_BUSY`.

In every case the production transaction returns the exact
error; the original PACKED source remains singly owned and
unpinned, the provisional FULL destination is absent from the
authoritative MM table, saved VM base stays zero, backing stays
unchanged, storage mode stays PACKED and TRANSITION stays held.
Every word of the original RAW suffix is compared. After removing
the one injected fault, FULL retries and succeeds with exactly
one unpinned PROCESS owner, resident VM/base publication, cleared
  backing, cleared TRANSITION, and word-identical reconstructed text
plus entire authoritative RAW suffix in the new destination.

## Independent invalid-code controls

The runner creates two disposable modified copies of the actual
v1391 source, compiles/links them with the SAME native oracle and
requires a nonzero executed `__test_exit` (not a build failure):

* `overlay`: omit the authoritative RAW suffix overlay. The new
  data-integrity oracle rejects with octal exit `0706`.
* `target-free`: omit target MM cleanup only after an invalid
  source-release refusal. The original v1395 baseline still
  passes, while the new v1648 source-free case rejects the leaked
  descriptor with octal exit `01004`.

Neither negative control is accepted as production source.

## Acceptance limits

Native source-linked FULL transaction and rollback verification,
not a new physical multi-process VFS/PI6 race. The v1647 real
DTVOL2 admission race, v1643 genuine secondary read failure and
v1638 physically pinned separate FULL destination remain separate
accepted evidence. Still OPEN: actual concurrent pinned FULL
restoration and provider changes, transient ambiguous MM failures,
entire 32K/64K peak RAM and KA10 machine-specific restoration.
PURE remains opt-in, optimization HOLD.
