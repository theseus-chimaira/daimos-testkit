# P1-E v1604: isolated PDP-6 PURE/MM regression review

Date: 2026-11-15. This is an isolated source-linked native PDP-6
regression, NOT production P1-E lifecycle activation. KA10 behavior
was NOT exercised. `DAIMOS_REPO=$HOME/git/DAIMOS` and
`PDP10_PREFIX=$HOME/cross` use current checkout/installed tools.

The following tests initially failed at **link time**, with
`dlink: undefined symbol: vfs_namespace_root`:

* `pure-ram-inplace-v1381/run-v1381.sh`
* `pure-ram-prefix-v1384/run-v1384.sh`
* `pure-ram-rollback-v1395/run-v1395.sh`

This is a real fixture link-dependency regression: the already
production-linked `proc_storage_runtime_v30.s` also includes the
root-vs-secondary `kcore_root_fs_io_failure_v1538` entry, which
reads `vfs_namespace_root`. The original symbol is now hosted in
the resident aliased MonitorFS device-accounting layout in
`system/kernel/drivers/device_state.s` (`mfsdev_io_in` slot 010).

All three runners now link the exact complete original
`device_state.s` alongside original `proc_storage_runtime_v30.s`.
There is no fabricated `vfs_namespace_root` variable, substitute
failure classifier, or changed production KCORE file.

Fresh outcomes after the fixture repair:

| Current-source native test | Result |
|---|---|
| v1381 inactive PURE MM descriptor rebase | PASS |
| v1384 in-place APR PURE prefix claim/release/commit | PASS |
| v1395/v1397 owner/pin/free rollback and FULL restore | PASS |
| v540 production MM move, APR reload and runqueue | PASS |

Run individually with:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
sh tests/validation/pure-ram-inplace-v1381/run-v1381.sh
sh tests/validation/pure-ram-prefix-v1384/run-v1384.sh
sh tests/validation/pure-ram-rollback-v1395/run-v1395.sh
sh tests/validation/daimos-mm-apr-handoff-v540.sh
```

Current reproducibility logs in `$TMPDIR`:
`p1e-review-v1381-v1604-retry.log`,
`p1e-review-v1384-v1604-retry.log`,
`p1e-review-v1395-v1604-retry.log`,
`p1e-review-v540-v1604.log`.

The original code is PDP-6-specific and unlinked from the current
swapless scheduler. The passing native tests do not prove KINIT,
PI6 lifecycle, whole-guest physical pressure, KA10 high/low
segment behavior, or exact production net RAM savings. These are
independent P1-E acceptance gates and remain on HOLD pending the
cross-machine review decision in
`DAIMOS/design/kcore-p1e-pdp6-ka10-architecture-review-v1604.md`.
