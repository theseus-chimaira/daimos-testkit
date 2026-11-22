# DAIMOS RAW PURE consolidation testkit v1804

The isolated `testkit-pure-integration-v1804` branch merges
the independent test branches `983c5fb` (v1684 source owner)
and `5fa1a2a` (v1682 stop/foreign control) into current testkit
main `3a4604e`, retaining both sets of native fixtures.
The detached DTFS v204 test fixture `c43d599` is ported
as an exact cherry-pick (new commit `10c32f4`).
All older worktrees, including their untracked fixtures, are
left intact. This is not merged to testkit main.

Run the source-level test gate:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export DAIMOS_REPO=/path/to/isolated/daimos-v1804
sh tests/validation/pure-integration-v1804/run-v1804.sh
```

This runs the K03 v1802 source contract, K04 v1801 read-only
historical physical witness verifier and v1684 source-linked
two-owner native test. Their success does **not** claim a new
physical integrated PDP-6 guest run, nor prove K05-K09 or
compressed mode3 safe to enable.

As of creation: K03 PASS (five negative mutants), K04 PASS
(ten verifier gates plus historical post-HALT/D6FS checks),
v1684 native PASS (two unsafe mount/backing guards rejected).
Physical 48K/64K RAW PURE and disk-root testing of the
combined v1804 kernel remains separately gated.
