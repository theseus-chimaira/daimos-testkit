# v1546: shared physical owner, ROOT/BACKSTORE first-failure ordering

Date: 2026-11-13. KCORE P0-A integrated native acceptance.

Both actual resident service paths are assembled together, without
reimplementing their failure classification: the D6FS block reader,
the complete `fs_backing.s` DSK270/DRM236 direct adapter, the fixed
`fs_mres.s` BACKSTORE DEVICE/VOLUME gateway, and the v1538/v1515
root/swap classifier and distinct HALT leaves. `p10run` executes
these genuine PDP-6 instructions. Only the bottom physical I/O
completion, BCACHE success/miss and the optional VOLUME mapper's
physical-unit translation are test-supplied. The two service paths
refer to the **same selected physical unit**, not different devices.

## Accepted native cases

Twelve combined cases PASS: root first and BACKSTORE first on both
DSK270 and DRM236; root first and BACKSTORE first with a mapped
VOLUME; mapped VOLUME service missing; BACKSTORE disabled but still
owning blocks; root success then fatal swap; swap success then fatal
root; both transfers successful; and a disabled, entirely unowned
BACKSTORE probe returning normally while root reads succeed.

Each fatal case checks the *exact* linked reason-specific HALT
instruction, never merely a halt at some PC. At every test endpoint
the test also checks that the original BACKSTORE block ownership
word is unchanged, and that the expected number of root and swap
service calls occurred. When the first service fails, the second
service must never be invoked. The native root and swap HALT labels
are distinguished from the invalid-reason HALT.

Five modifications to genuine source are rejected: swap failure
misrouted as root, root failure misrouted as swap, disabled-but-owned
swap check bypassed, mapped VOLUME error bypassed, and incorrect
selected-root mount comparison. Tests use no new KCORE data or ABI.

Run:

```
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
sh tests/validation/daimos-shared-root-backstore-v1546.sh
```

## Remaining physical qualification

This **does not** establish a full-guest shared-media outage or
hardware arbitration between competing in-flight root and swap
requests. Bottom-of-stack outcomes are controlled native fixtures;
the mapper is a fixture only, so actual BLOCKSET MRES lifecycle
must be checked in a booted physical guest before closing P0-A.

Already accepted physical gates: v1538-v1543 selected root losses,
v1542 actual Type-236 PI2 BACKSTORE error, and v1545 independent
mounted secondary D6FS disk/drum failures. A combined shared-device
positive physical fault and retained critical ownership remain OPEN.
