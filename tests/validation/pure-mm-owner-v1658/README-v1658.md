# v1658 native PDP-6 PURE MM terminal ownership gate

Source baseline: DAIMOS v1657 `2370e0b1ae173a92d8d1b70e42684a1ffc9cd0c8`.
Development branch: `kcore-mm-uncertain-v1658-20261117`.

The runner compiles the actual opt-in v1381 DROP, v1384 PREFIX,
v1391 FULL and v1612 service sources with KCC, links the actual PDP-6
MM rebase/claim/commit/release and storage publication assembly, and
executes them in the PDP-6 model. Only physical memory/provider and
injected unpin failure conditions are native fixtures.

Coverage:

1. Original v1654 FULL source/target pin and free/rollback matrix,
   followed by native v1612 ONE-owner service and unsafe READY_ONCE mutant.
2. Actual successful PREFIX service: exactly one unpinned PROCESS APR,
   RESIDENT, original writable data intact, and cleared TRANSITION.
3. A second unpin of that same APR must return MM_ERR_INVAL, proving
   the atomic commit already consumed the sole transaction pin.
4. Actual DROP rebase whose unpin succeeded but the call reported BUSY:
   verified unpinned PACKED owner can be unlocked and compacted.
5. Actual DROP rebase whose unpin never succeeded: original PACKED
   owner stays pinned, transition-held, no READY_ONCE, no blind retry.
6. Independently assembled/executed unsafe MM mutant that removes the
   pin decrement must be rejected by the native owner oracle.

Reproduce against the updated DAIMOS source worktree:

```
export TMPDIR="$HOME/tmp"
export PDP10_PREFIX="$HOME/cross"
export DAIMOS_REPO=/path/to/v1658/DAIMOS
sh tests/validation/pure-mm-owner-v1658/run-v1658.sh
```

The runner retains versioned original positive and negative logs in its
printed `$TMPDIR/daimos-mm-owner-v1658.*` directory. Never treat a mutant
compile/link failure as an executed negative proof.

For the independent source-built 48K physical lifecycle and actual
secondary DTC3 failure/recovery (not a scheduler test bypass), first
build the original source-derived guest with:

```
sh tests/diagnostics/pure-secondary-read-v1643/run-v1643.sh
```

The output identifies an actual new `pure-brk-pressure-v1614.*`
directory. Set `PURE_MM_BUILD_V1658` to its `build` subdirectory,
preserving the actual source-linked `pure-mres-v1612.map`, and run:

```
export PURE_MM_BUILD_V1658="$TMPDIR/pure-brk-pressure-v1614.<id>/build"
sh tests/validation/pure-mm-owner-v1658/run-physical-v1658.sh
```

The physical preflight verifies the exact new v1658 MRES function
offsets and four original instruction words before recentering the
existing v1643 replay/audit. It does NOT change the original 48K
guest, six-owner MM trace, DTC3 source failure, recovery, WAIT/HALT
or forged-pin / forged-success negative checks. The original physical
simulator, strict auditor and both negative oracles ran; the complete
v1658 derived physical runner finished with exit 0.

The separate normal 48K source-built guest has passed original child
PIPE/WAIT/EXIT and HALT at PC 000000 with unchanged fixed KCORE SHA256
88970ee633dc22094565172348bc1dcb9f49ba0417e104fb5608b71a87668d01.
No 64K acceptance or full source-toolchain release freeze is implied.
Production mode3 compression and continuous RAM accounting remain open.
