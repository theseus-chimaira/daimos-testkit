# Native KCORE DTFS PURE owner acceptance v1563

Date: 2026-11-14. The v1555 DTVOL2 READ-ONLY veto remains enabled.

Run against the current DAIMOS checkout:

```sh
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-pure-attach-v1563.sh
sh tests/validation/daimos-dtfs-pure-native-v1563.sh
sh tests/validation/daimos-dtfs-pure-staging-v1563.sh
```

`daimos-dtfs-pure-attach-v1563.sh` compiles the real production C89
`proc_swap_attach()` on host with an injection boundary for the real
VFS barrier, checking unchanged resident backing and staged mount bits
on refusal and unchanged non-DTFS policy.

`daimos-dtfs-pure-native-v1563.sh` compiles the actual C implementation
with KCC for PDP-6 and links the actual source leaf
`vfs_dtfs_owner_admit_v1562` from `vfs.s`, not a model of its logic.
Eleven source-linked native scenarios PASS with both an inverted attach
gate and an inverted VFS media barrier mutation rejected.

`daimos-dtfs-pure-staging-v1563.sh` executes the actual native
`proc_swap_backing_busy` and `proc_swap_mount_busy` leaf instructions.
Its 26 scenarios cover SIDL without u-area, SIDL after u-area allocation
but before credential publication, public mount IDs 1/16/17/26,
SRUN resident and swapped backed images, and non-PURE exclusions.
All six unsafe source mutations are rejected by the native oracle.

Legacy regression acceptance: v960/v961 host C89 packing, v1382 native
PURE/MM backing (standalone namespace-root stub refreshed), v1523
FILE/cwd, v1562 full actual VFS unmount and owner admission, and
PIPE mount-reference v19/v417. The legacy v1084 FIFO interrupted OPEN
test fixture was repaired to link the current actual FILE lookup leaf,
provide unrelated DTFS-only symbols and expect exact MM pinned extent
refusal `-5` from the current PIPE close ABI. It now passes its native
pinned-rollback, FD retention, retry and last-close checks.

Full 256K-profile KCC KCORE/optional DTFS MRES assemble/fold/link/image
PASS. Relative to v1562, the KCORE low-end moves from octal `024266`
to octal `024330`, i.e. 34 additional fixed TEXT words; no DATA/BSS,
mount-slab or process-table growth. No physical CLEAN or active
RW DTVOL2 is enabled, and strict 32K placement is still on HOLD.
