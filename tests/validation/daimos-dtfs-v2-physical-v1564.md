# Native DTVOL2/CLEAN and WRITE_INTENT physical PDP-6 acceptance v1564

Date: 2026-11-14. KCORE feature work P0-B; **read-only only**.

## Running the physical test

```sh
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-v2-fullguest-v1564.sh
```

The first invocation builds a private current full KCC 256K TSFS-root
image. To reuse an exact already-built image, set
`DAIMOS_TSFS_PREBUILT_BUILD` to its *real existing* directory.
`DAIMOS_TSFS_KEEP_WORK=1` preserves physical simulator transcripts.

Both tests reuse the physical booted-PDP-6 infrastructure of v1525
and the independent PID1/PID2 process scheduling and pipe rendezvous
of v1526. Neither test injects a mocked VFS, DTFS, PI, syscall,
ownership table, or fake physical data: the actual KCORE DTFS MRES,
Type-551/136 DTC3 transfer path and physical `mkdtfs` output run.
The only C changes to the existing v1526 gate are conditional
`DAIMOS_DTFS_V2_PHYSICAL_V1564` test-only checks and log labels.

## Boot 1: physically CLEAN DTVOL2

- Compile the current production host `mkdtfs.c` in the isolated
  test directory, format the *disposable* DTC3 image with explicit
  `--durable-v1550`, and independently verify all 128 RBN0 words:
  DTVOL2 SIXBIT magic, nonzero 72-bit ID, exact 36-bit identity
  complement, CLEAN state, independent salted seal and zero padding.
- Verify the real physical RBN0144 directory owner map uses C index
  14 / PDP-6 assembly `+016`; record SHA-256 of the whole tape.
- Full-guest PID1 first attempts RW native DTVOL2 mount. The kernel
  must refuse and leave the slot unpublished. A subsequent RO mount
  succeeds; PID1 is independently scheduled against PID2 (a RUN of
  `/SYSTEM/INIT`) synchronized with two real anonymous pipes.
- The child alone holds cwd, then FILE; unmount refuses both cases.
  After closing both, the still-live child is allowed to continue
  while the parent unmounts. After child exit/reap, another RW mount
  is denied, a second RO mount succeeds, and its final unmount retires.
- The independent full-tape SHA-256 **must remain identical** at
  the end. No physical DATA/DIR/RBN0 write is permitted.

Guest CTY stages: `DTFSV2 V1564 START`, `RW_REFUSED`, `MOUNTED`,
`CHILD_START`, `CROSS_CWD_REFUSED`, `CROSS_FILE_REFUSED`,
`CROSS_RETIRED`, `CHILD_DONE`, `REMOUNTED`, `PASS`.

## Boot 2: physically WRITE_INTENT DTVOL2

- Create another independent valid DTVOL2 tape and rewrite *only*
  its RBN0 intent state and salted seal to the exact valid
  `WRITE_INTENT` encoding. Verify all other RBN0 words, its identity
  and the directory owner map. Capture its full SHA-256 before boot.
- Cold boot the exact same KCORE with this disposable DTC3 image.
  Both RW **and** RO mounts must be refused. The public mount slot
  must stay absent; even an unmount command on the unused mountpoint
  must not succeed.
- Verify the full tape SHA-256 unchanged after the real guest HALT.

Guest CTY stages: `DTFSV2DIRTY V1564 START`, `RW_REFUSED`,
`RO_REFUSED`, `UNPUBLISHED`, `PASS`.

## Accepted result

Two physically booted 256K KCC PDP-6 guests and both full-tape
post-execution SHA-256 checks **PASS**. The existing v1525
test runner's expected-stage and simulator checks were reused.

Scope limitation: the DIRTY image was deliberately formatted as
though a previous WRITE_INTENT operation had reached physical RBN0.
This test does **not** establish atomic/torn CLEAN writing, physical
RW data durability, actual tape replacement during a sleeping I/O,
or the media generation/exchange contract. A separately timed
simultaneous FILE/PIPE/EXEC admission attempt during sleeping SYNC
is also not covered by this run: the independently scheduled child
owns cwd/FILE while its parent attempts unmount.

**P0-B OPEN, DTVOL2 remains READ-ONLY, strict 32K optimization HOLD.**
No DAIMOS production kernel or MRES source was changed in v1564.
